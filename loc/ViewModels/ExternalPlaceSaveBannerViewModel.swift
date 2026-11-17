//
//  ExternalPlaceSaveBannerViewModel.swift
//  loc
//
//  ViewModel for the "Saved to …" banner on the Detected Places screen.
//  Single Responsibility: saves detected places into Saved (when auto-sort is on) and owns the banner.
//

import Foundation

@MainActor
class ExternalPlaceSaveBannerViewModel: ObservableObject {
    @Published private(set) var message: String?
    /// The places the banner refers to; "Add to list" targets exactly these.
    private(set) var savedPlaces: [DetailPlace] = []
    private var dismissTask: Task<Void, Never>?

    /// Saves unsaved places to Saved and shows the banner; returns false when the caller should open the list picker.
    @discardableResult
    func autoSave(_ places: [DetailPlace], favorites: ProfileFavoritesViewModel) -> Bool {
        guard SavedLibraryGate.isEnabled else { return false }
        let fresh = ImportAutoSave.placesToSave(from: places, alreadySaved: [])
            .filter { !favorites.isPlaceFavorite(placeId: $0.id.uuidString) }
        guard !fresh.isEmpty else { return false }
        fresh.forEach { favorites.addFavoritePlace(place: $0) }
        savedPlaces = fresh
        message = ImportAutoSave.bannerMessage(for: fresh)
        scheduleDismiss()
        return true
    }

    /// Hides the banner.
    func dismiss() {
        dismissTask?.cancel()
        message = nil
    }

    /// Hides the banner automatically after a few seconds.
    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
