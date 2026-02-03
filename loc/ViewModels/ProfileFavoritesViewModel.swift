//
//  ProfileFavoritesViewModel.swift
//  loc
//
//  Extracted from ProfileViewModel for favorites management.
//

import SwiftUI

/// Manages favorite places for the current user's profile.
@MainActor
class ProfileFavoritesViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Legacy array of favorite place IDs
    @Published var userFavorites: [String] = []

    /// Lightweight favorites data for display
    @Published var lightweightFavorites: [FavoritePlace] = []

    /// Alert shown when max favorites limit is reached
    @Published var showMaxFavoritesAlert: Bool = false

    // MARK: - Callbacks for Cross-Cutting Concerns

    /// Called when placeSavers dictionary needs updating for map display
    var onPlaceSaversUpdate: ((String, String, Bool) -> Void)?

    /// Called when annotation places need recalculating
    var onAnnotationPlacesRecalculate: (() -> Void)?

    // MARK: - Dependencies

    private weak var userSession: UserSession?

    // MARK: - Initialization

    /// Initializes the favorites view model with required dependencies.
    init(userSession: UserSession) {
        self.userSession = userSession
    }

    // MARK: - Computed Properties

    /// Converts lightweightFavorites to LightweightPlace format for consistent popup display.
    var favoritesAsLightweight: [LightweightPlace] {
        lightweightFavorites.map { favorite in
            LightweightPlace(
                place_id: favorite.place_id,
                name: favorite.name,
                latest_review_photo: favorite.latest_review_photo,
                external_place_id: nil,
                tiktok_url: nil,
                added_by_user_id: nil,
                added_by_name: nil,
                added_by_photo_url: nil
            )
        }
    }

    // MARK: - Public Methods

    /// Adds a place to favorites with server-side validation.
    func addFavoritePlace(place: DetailPlace) {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileFavoritesViewModel] Cannot add favorite: no user ID")
            return
        }

        let placeId = place.id.uuidString

        // Quick client-side check (server will also validate)
        if lightweightFavorites.contains(where: { $0.place_id == placeId }) {
            return
        }

        // Optimistic UI update - add immediately for responsive UX
        let newFavorite = FavoritePlace(
            place_id: placeId,
            name: place.name,
            latest_review_photo: place.photoUrls?.first
        )
        lightweightFavorites.append(newFavorite)

        // Also update legacy userFavorites array
        if !userFavorites.contains(placeId) {
            userFavorites.append(placeId)
        }

        // Update placeSavers for map display (via callback)
        onPlaceSaversUpdate?(placeId, userId, true)

        // Persist using FavoritesService (server-side validation)
        Task {
            let result = await FavoritesService.shared.addFavorite(userId: userId, placeId: placeId)

            await MainActor.run {
                switch result {
                case .success:
                    // Success - optimistic update was correct
                    self.onAnnotationPlacesRecalculate?()

                case .maxLimit:
                    // Server says max limit - revert and show alert
                    print("⚠️ [ProfileFavoritesViewModel] Server rejected: max favorites reached")
                    self.revertFavoriteAdd(placeId: placeId, userId: userId)
                    self.showMaxFavoritesAlert = true

                case .duplicate:
                    // Already favorited on server - keep local state as is
                    break

                case .error(let error):
                    // Error - revert optimistic update
                    print("❌ [ProfileFavoritesViewModel] Error adding favorite: \(error)")
                    self.revertFavoriteAdd(placeId: placeId, userId: userId)
                }
            }
        }
    }

    /// Removes a place from favorites.
    func removeFavoritePlace(place: DetailPlace) {
        guard let userId = userSession?.currentUserId else {
            print("⚠️ [ProfileFavoritesViewModel] Cannot remove favorite: no user ID")
            return
        }

        let placeId = place.id.uuidString

        // Store for potential revert
        let removedFavorite = lightweightFavorites.first { $0.place_id == placeId }

        // Optimistic UI update - remove immediately
        lightweightFavorites.removeAll { $0.place_id == placeId }
        userFavorites.removeAll { $0 == placeId }

        // Persist using FavoritesService
        Task {
            do {
                try await FavoritesService.shared.removeFavorite(userId: userId, placeId: placeId)
            } catch {
                // Revert optimistic update on failure
                print("❌ [ProfileFavoritesViewModel] Error removing favorite: \(error)")
                await MainActor.run {
                    if let favorite = removedFavorite {
                        self.lightweightFavorites.append(favorite)
                    }
                    if !self.userFavorites.contains(placeId) {
                        self.userFavorites.append(placeId)
                    }
                }
            }
        }
    }

    /// Checks if a place is in the user's favorites.
    func isPlaceFavorite(placeId: String) -> Bool {
        return lightweightFavorites.contains(where: { $0.place_id == placeId }) || userFavorites.contains(placeId)
    }

    /// Resets all favorites data (used during logout).
    func resetAllData() {
        userFavorites.removeAll()
        lightweightFavorites.removeAll()
        showMaxFavoritesAlert = false
    }

    // MARK: - Private Methods

    /// Reverts an optimistic favorite add.
    private func revertFavoriteAdd(placeId: String, userId: String) {
        lightweightFavorites.removeAll { $0.place_id == placeId }
        userFavorites.removeAll { $0 == placeId }
        onPlaceSaversUpdate?(placeId, userId, false)
    }
}
