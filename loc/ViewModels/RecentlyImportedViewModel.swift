//
//  RecentlyImportedViewModel.swift
//  loc
//
//  Single Responsibility: Owns the "Recently imported" profile tab's Near me / All scope and
//  produces the places that tab shows. "All" mirrors the user's paginated imports from
//  ProfileExternalContentViewModel; "Near me" fetches the user's own imports inside a bounding
//  box around their current location and trims them to a 20-mile radius.
//

import Combine
import CoreLocation
import Foundation

/// Drives the profile's "Recently imported" tab and its Near me / All toggle.
@MainActor
final class RecentlyImportedViewModel: ObservableObject {
    // MARK: - Constants

    /// Radius used by "Near me": 20 miles.
    nonisolated static let nearbyRadiusMeters: CLLocationDistance = 32_187

    /// Max imports fetched for "Near me" (the profile preview shows 6; the rest is headroom).
    private static let nearbyFetchLimit = 60

    /// How far the user must move before "Near me" is refetched.
    private static let refetchDistanceMeters: CLLocationDistance = 1_600

    /// UserDefaults key that remembers the last scope the user picked.
    static let scopeDefaultsKey = "profileRecentlyImportedScope"

    // MARK: - Published State

    /// The scope the user picked (defaults to All). Persisted so the profile opens the way they left it.
    @Published private(set) var scope: RecentlyImportedScope

    /// The user's recent imports, newest first (mirrors the profile's existing Videos data).
    @Published private(set) var allPlaces: [LightweightPlace] = []

    /// Whether the "All" data is still loading.
    @Published private(set) var isLoadingAll: Bool = false

    /// The user's recent imports within the nearby radius, newest first.
    @Published private(set) var nearbyPlaces: [LightweightPlace] = []

    /// Whether a "Near me" fetch is in flight.
    @Published private(set) var isLoadingNearby: Bool = false

    /// Whether at least one "Near me" fetch has finished for the current location.
    @Published private(set) var hasLoadedNearby: Bool = false

    /// The last location used for "Near me"; nil until location is authorized and a fix arrives.
    @Published private(set) var currentLocation: CLLocation?

    /// Set while the map is showing this tab's "Near me" results (opened from the profile grid).
    @Published private(set) var mapNearMeLocation: CLLocation?

    // MARK: - Derived State

    /// Whether the tab is actually showing nearby results (Near me picked and a location is known).
    var isShowingNearby: Bool { scope == .nearMe && currentLocation != nil }

    /// Whether Near me is picked but there is no location, so the tab falls back to All.
    var isLocationUnavailable: Bool { scope == .nearMe && currentLocation == nil }

    /// The places the tab should render for the current scope.
    var displayedPlaces: [LightweightPlace] { isShowingNearby ? nearbyPlaces : allPlaces }

    /// Whether the tab should show its loading state instead of the grid.
    var isLoading: Bool {
        if isShowingNearby {
            return nearbyPlaces.isEmpty && (isLoadingNearby || !hasLoadedNearby)
        }
        return isLoadingAll
    }

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?
    private let defaults: UserDefaults
    private var nearbyRequestId: Int = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates the view model and subscribes to the user's imports and location updates.
    init(
        userService: UserService,
        userSession: UserSession,
        allPlacesPublisher: AnyPublisher<[LightweightPlace], Never>,
        isLoadingAllPublisher: AnyPublisher<Bool, Never>,
        locationPublisher: AnyPublisher<CLLocation?, Never>,
        defaults: UserDefaults = .standard
    ) {
        self.userService = userService
        self.userSession = userSession
        self.defaults = defaults
        self.scope = defaults.string(forKey: Self.scopeDefaultsKey)
            .flatMap(RecentlyImportedScope.init(rawValue:)) ?? .all
        subscribeToImports(allPlacesPublisher, isLoading: isLoadingAllPublisher)
        subscribeToLocation(locationPublisher)
        subscribeToUser(userSession)
    }

    // MARK: - Intents

    /// Switches between Near me and All, remembers the choice, and loads nearby results if needed.
    func selectScope(_ newScope: RecentlyImportedScope) {
        guard newScope != scope else { return }
        scope = newScope
        defaults.set(newScope.rawValue, forKey: Self.scopeDefaultsKey)
        if newScope == .nearMe && !hasLoadedNearby {
            reloadNearbyPlaces()
        }
    }

    /// Records whether the map about to open should match "Near me" (only when nearby results are showing).
    func prepareMapScope() {
        mapNearMeLocation = isShowingNearby ? currentLocation : nil
    }

    /// Stops the map matching "Near me"; called when the map's imports sheet closes.
    func clearMapScope() {
        mapNearMeLocation = nil
    }

    /// Clears all per-user state; called on logout.
    func resetAllData() {
        mapNearMeLocation = nil
        nearbyRequestId += 1
        nearbyPlaces = []
        isLoadingNearby = false
        hasLoadedNearby = false
    }

    // MARK: - Subscriptions

    /// Mirrors the user's imports for "All" and refetches "Near me" when the newest imports change.
    private func subscribeToImports(
        _ places: AnyPublisher<[LightweightPlace], Never>,
        isLoading: AnyPublisher<Bool, Never>
    ) {
        places
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.allPlaces = $0 }
            .store(in: &cancellables)

        isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isLoadingAll = $0 }
            .store(in: &cancellables)

        // An import or delete changes the newest ids; pagination only appends, so it doesn't.
        places
            .map { Array($0.prefix(8).map(\.place_id)) }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reloadNearbyIfAlreadyLoaded() }
            .store(in: &cancellables)
    }

    /// Tracks the user's location and refetches "Near me" once they have moved a meaningful distance.
    private func subscribeToLocation(_ locations: AnyPublisher<CLLocation?, Never>) {
        locations
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] location in self?.handleLocationUpdate(location) }
            .store(in: &cancellables)
    }

    /// Fetches "Near me" once a signed-in user is known (the location fix can arrive before the session).
    private func subscribeToUser(_ userSession: UserSession) {
        userSession.$currentUserId
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadNearbyIfAlreadyLoaded() }
            .store(in: &cancellables)
    }

    /// Stores a new location when it is the first fix or far enough from the last one.
    private func handleLocationUpdate(_ location: CLLocation) {
        if let current = currentLocation,
           current.distance(from: location) < Self.refetchDistanceMeters {
            return
        }
        currentLocation = location
        hasLoadedNearby = false
        if scope == .nearMe {
            reloadNearbyPlaces()
        }
    }

    // MARK: - Loading

    /// Refetches nearby imports when Near me is picked or has already been loaded once.
    private func reloadNearbyIfAlreadyLoaded() {
        guard hasLoadedNearby || scope == .nearMe else { return }
        reloadNearbyPlaces()
    }

    /// Starts a "Near me" fetch for the current location, superseding any fetch in flight.
    private func reloadNearbyPlaces() {
        guard let location = currentLocation, let userId = userSession?.currentUserId else { return }
        nearbyRequestId += 1
        let requestId = nearbyRequestId
        isLoadingNearby = true
        Task { [weak self] in
            await self?.fetchNearbyPlaces(userId: userId, around: location, requestId: requestId)
        }
    }

    /// Fetches the user's imports inside the bounding box and keeps those within the radius.
    private func fetchNearbyPlaces(userId: String, around location: CLLocation, requestId: Int) async {
        let box = Self.boundingBox(around: location.coordinate, radiusMeters: Self.nearbyRadiusMeters)
        let result: [LightweightPlace]?
        do {
            result = try await userService.fetchUserExternalPlaces(
                userId: userId, limit: Self.nearbyFetchLimit, offset: 0, viewport: box
            )
        } catch {
            print("❌ [RecentlyImportedViewModel] Error loading nearby imports: \(error.localizedDescription)")
            result = nil
        }
        guard requestId == nearbyRequestId else { return }
        if let result {
            nearbyPlaces = Self.places(result, within: Self.nearbyRadiusMeters, of: location)
        }
        isLoadingNearby = false
        hasLoadedNearby = true
    }

    // MARK: - Geometry

    /// Returns a lon/lat bounding box that fully contains a circle of the given radius.
    nonisolated static func boundingBox(
        around center: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance
    ) -> (minLon: Double, minLat: Double, maxLon: Double, maxLat: Double) {
        let metersPerDegree = 111_320.0
        let latDelta = radiusMeters / metersPerDegree
        let cosLat = max(cos(center.latitude * .pi / 180), 0.01)
        let lonDelta = radiusMeters / (metersPerDegree * cosLat)
        return (
            minLon: center.longitude - lonDelta,
            minLat: max(center.latitude - latDelta, -90),
            maxLon: center.longitude + lonDelta,
            maxLat: min(center.latitude + latDelta, 90)
        )
    }

    /// Keeps places with coordinates within the radius of a location, preserving order and dropping duplicates.
    nonisolated static func places(
        _ places: [LightweightPlace],
        within radiusMeters: CLLocationDistance,
        of location: CLLocation
    ) -> [LightweightPlace] {
        var seenIds = Set<String>()
        return places.filter { place in
            guard let lat = place.latitude, let lon = place.longitude else { return false }
            let distance = location.distance(from: CLLocation(latitude: lat, longitude: lon))
            return distance <= radiusMeters && seenIds.insert(place.place_id).inserted
        }
    }
}
