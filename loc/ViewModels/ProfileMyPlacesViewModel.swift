//
//  ProfileMyPlacesViewModel.swift
//  loc
//
//  Extracted from ProfileViewModel for user-created places management.
//

import SwiftUI

/// Manages user-created places (My Places) for the current user's profile.
@MainActor
class ProfileMyPlacesViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Lightweight my places data for display
    @Published var lightweightMyPlaces: [LightweightPlace] = []

    /// Total count of my places from database
    @Published var totalMyPlacesCount: Int = 0

    /// Loading state for initial load
    @Published var isMyPlacesLoading: Bool = true

    /// Loading state for pagination
    @Published var isLoadingMoreMyPlaces: Bool = false

    /// Whether more places can be loaded
    @Published var hasMoreMyPlaces: Bool = true

    /// Legacy array of place IDs
    @Published var myPlaces: [String] = []

    // MARK: - Callbacks for Cross-Cutting Concerns

    /// Called when placeSavers dictionary needs updating for map display
    var onPlaceSaversUpdate: ((String, String, Bool) -> Void)?

    /// Called when a place needs to be removed from map annotations
    var onPlaceRemoveFromAnnotations: ((String) -> Void)?

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?

    // MARK: - Constants

    private let placesPerPage: Int = 8

    // MARK: - Initialization

    /// Initializes the my places view model with required dependencies.
    init(userService: UserService, userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
    }

    // MARK: - Public Methods

    /// Loads the initial page of my places.
    func loadInitialMyPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileMyPlacesViewModel] Cannot load initial my places: no user ID")
            return
        }

        // Don't reload if already loading or if we have data
        guard !isMyPlacesLoading || lightweightMyPlaces.isEmpty else {
            return
        }

        isMyPlacesLoading = true

        defer {
            isMyPlacesLoading = false
        }

        do {
            // Fetch first page of lightweight places and total count in parallel
            async let placesTask = userService.fetchUserCreatedPlaces(userId: userId, limit: placesPerPage, offset: 0)
            async let countTask = userService.getNumberCreatedPlaces(forUserId: userId)

            let lightweightPlaces = try await placesTask
            let totalCount = (try? await countTask) ?? 0

            // Update state: replace existing places and update hasMore flag
            lightweightMyPlaces = lightweightPlaces
            myPlaces = lightweightPlaces.map { $0.place_id }
            totalMyPlacesCount = totalCount
            hasMoreMyPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= placesPerPage

            // Add the current user as a saver for their own places (for map display)
            for place in lightweightPlaces {
                onPlaceSaversUpdate?(place.place_id, userId, true)
            }
        } catch {
            print("❌ [ProfileMyPlacesViewModel] Error loading initial my places: \(error.localizedDescription)")
            hasMoreMyPlaces = false
        }
    }

    /// Loads more my places (pagination).
    func loadMoreMyPlaces() async {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileMyPlacesViewModel] Cannot load more my places: no user ID")
            return
        }

        // Guard: prevent multiple simultaneous loads and check if more data is available
        guard !isLoadingMoreMyPlaces && hasMoreMyPlaces else {
            return
        }

        // Calculate offset based on current count
        let offset = lightweightMyPlaces.count

        isLoadingMoreMyPlaces = true

        defer {
            isLoadingMoreMyPlaces = false
        }

        do {
            // Fetch next page of lightweight places
            let lightweightPlaces = try await userService.fetchUserCreatedPlaces(userId: userId, limit: placesPerPage, offset: offset)

            // Deduplicate to prevent SwiftUI rendering issues
            let existingIds = Set(lightweightMyPlaces.map { $0.id })
            let newUniquePlaces = lightweightPlaces.filter { !existingIds.contains($0.id) }

            if !newUniquePlaces.isEmpty {
                lightweightMyPlaces.append(contentsOf: newUniquePlaces)
                myPlaces.append(contentsOf: newUniquePlaces.map { $0.place_id })

                // Add the current user as a saver for their own places (for map display)
                for place in newUniquePlaces {
                    onPlaceSaversUpdate?(place.place_id, userId, true)
                }

                let duplicateCount = lightweightPlaces.count - newUniquePlaces.count
                if duplicateCount > 0 {
                    print("⚠️ [ProfileMyPlacesViewModel] Filtered \(duplicateCount) duplicate places")
                }
            } else if !lightweightPlaces.isEmpty {
                print("⚠️ [ProfileMyPlacesViewModel] All \(lightweightPlaces.count) places were duplicates")
            }

            // Update hasMore flag: false if empty or if we got less than a full page
            hasMoreMyPlaces = !lightweightPlaces.isEmpty && lightweightPlaces.count >= placesPerPage
        } catch {
            print("❌ [ProfileMyPlacesViewModel] Error loading more my places: \(error.localizedDescription)")
            hasMoreMyPlaces = false
        }
    }

    /// Removes a place from local state (called after deletion).
    func removeFromLocalState(placeId: String) {
        guard let userId = userSession?.currentUserId else { return }

        // Remove from lightweight places array
        lightweightMyPlaces.removeAll { $0.place_id == placeId }

        // Remove from ID tracking collection
        myPlaces.removeAll { $0 == placeId }

        // Update total count
        if totalMyPlacesCount > 0 {
            totalMyPlacesCount -= 1
        }

        // Remove from map annotations (via callback)
        onPlaceRemoveFromAnnotations?(placeId)

        // Remove from placeSavers (via callback)
        onPlaceSaversUpdate?(placeId, userId, false)
    }

    /// Resets all my places data (used during logout).
    func resetAllData() {
        lightweightMyPlaces.removeAll()
        myPlaces.removeAll()
        totalMyPlacesCount = 0
        isMyPlacesLoading = true
        isLoadingMoreMyPlaces = false
        hasMoreMyPlaces = true
    }
}
