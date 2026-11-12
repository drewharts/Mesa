//
//  RecentlyImportedViewModel.swift
//  loc
//
//  Single Responsibility: Owns the All / Near me scope of the map's imports sheet (opened from the
//  profile's "Recently imported" tab) and produces the places that sheet and its pins show.
//  "All" mirrors the user's paginated imports from ProfileExternalContentViewModel; "Near me" fetches the user's own imports inside a bounding
//  box around their current location and trims them to a 20-mile radius.
//

import Combine
import CoreLocation
import Foundation

/// Drives the All / Near me toggle in the map's imports sheet.
@MainActor
final class RecentlyImportedViewModel: ObservableObject {
    // MARK: - Constants

    /// Radius used by "Near me": 20 miles.
    nonisolated static let nearbyRadiusMeters: CLLocationDistance = 32_187

    /// Max imports fetched for "Near me".
    private static let nearbyFetchLimit = 200

    /// How far the user must move before "Near me" is refetched.
    private static let refetchDistanceMeters: CLLocationDistance = 1_600

    // MARK: - Published State

    /// The scope picked in the map's imports sheet. Starts at All each time the sheet opens.
    @Published private(set) var scope: RecentlyImportedScope = .all

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

    /// Center the map's pins are limited to while Near me is showing; nil shows all imports.
    @Published private(set) var mapNearMeLocation: CLLocation?

    // MARK: - Derived State

    /// Whether Near me can be picked (a location is known).
    var isNearMeAvailable: Bool { currentLocation != nil }

    /// Whether nearby results are showing (Near me picked and a location is known).
    var isShowingNearby: Bool { scope == .nearMe && currentLocation != nil }

    /// The places the sheet should list for the current scope.
    var displayedPlaces: [LightweightPlace] { isShowingNearby ? nearbyPlaces : allPlaces }

    /// Whether the nearby list is still waiting on its first results.
    var isLoadingNearbyResults: Bool {
        isShowingNearby && nearbyPlaces.isEmpty && (isLoadingNearby || !hasLoadedNearby)
    }

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?
    private var nearbyRequestId: Int = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates the view model and subscribes to the user's imports and location updates.
    init(
        userService: UserService,
        userSession: UserSession,
        allPlacesPublisher: AnyPublisher<[LightweightPlace], Never>,
        isLoadingAllPublisher: AnyPublisher<Bool, Never>,
        locationPublisher: AnyPublisher<CLLocation?, Never>
    ) {
        self.userService = userService
        self.userSession = userSession
        subscribeToImports(allPlacesPublisher, isLoading: isLoadingAllPublisher)
        subscribeToLocation(locationPublisher)
        subscribeToUser(userSession)
    }

    // MARK: - Intents

    /// Switches between All and Near me, updates the map's pin filter, and loads nearby results if needed.
    func selectScope(_ newScope: RecentlyImportedScope) {
        guard newScope != scope else { return }
        guard newScope == .all || isNearMeAvailable else { return }
        scope = newScope
        updateMapNearMeLocation()
        if newScope == .nearMe && !hasLoadedNearby {
            reloadNearbyPlaces()
        }
    }

    /// Resets the sheet to All; called when the map's imports sheet closes.
    func resetScope() {
        scope = .all
        updateMapNearMeLocation()
    }

    /// Clears all per-user state; called on logout.
    func resetAllData() {
        resetScope()
        nearbyRequestId += 1
        nearbyPlaces = []
        isLoadingNearby = false
        hasLoadedNearby = false
    }

    /// Publishes the map's pin-filter center for the current scope and location.
    private func updateMapNearMeLocation() {
        let center = isShowingNearby ? currentLocation : nil
        if center !== mapNearMeLocation { mapNearMeLocation = center }
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
            .sink { [weak self] _ in self?.reloadNearbyPlaces() }
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
            .sink { [weak self] _ in self?.reloadNearbyPlaces() }
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
        updateMapNearMeLocation()
        // Prefetch so Near me is instant when picked in the sheet.
        reloadNearbyPlaces()
    }

    // MARK: - Loading

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
