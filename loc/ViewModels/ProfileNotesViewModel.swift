//
//  ProfileNotesViewModel.swift
//  loc
//
//  Extracted from ProfileViewModel for place notes management.
//

import SwiftUI

/// Manages place notes for the current user's profile.
@MainActor
class ProfileNotesViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Place notes by place ID
    @Published var placeNotes: [String: PlaceNote] = [:]

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?

    // MARK: - Initialization

    /// Initializes the notes view model with required dependencies.
    init(userService: UserService, userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
    }

    // MARK: - Public Methods

    /// Saves a place note (creates or updates).
    func savePlaceNote(for placeId: String, note: String?, link: String?) {
        guard let userId = userSession?.currentUserId else { return }

        let placeNote = PlaceNote(placeId: placeId, userId: userId, note: note, link: link)

        userService.savePlaceNote(note: placeNote) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.placeNotes[placeId] = placeNote
                }
            } else if let error = error {
                print("❌ [ProfileNotesViewModel] Error saving place note: \(error.localizedDescription)")
            }
        }
    }

    /// Loads a place note from the database.
    func loadPlaceNote(for placeId: String) {
        guard let userId = userSession?.currentUserId else { return }

        userService.fetchPlaceNote(userId: userId, placeId: placeId) { [weak self] placeNote, error in
            DispatchQueue.main.async {
                if let placeNote = placeNote {
                    self?.placeNotes[placeId] = placeNote
                }
            }
        }
    }

    /// Deletes a place note from the database.
    func deletePlaceNote(for placeId: String) {
        guard let userId = userSession?.currentUserId,
              let placeNote = placeNotes[placeId] else { return }

        userService.deletePlaceNote(userId: userId, placeId: placeNote.placeId) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.placeNotes.removeValue(forKey: placeId)
                }
            } else if let error = error {
                print("❌ [ProfileNotesViewModel] Error deleting place note: \(error.localizedDescription)")
            }
        }
    }

    /// Gets a place note for a specific place.
    func getPlaceNote(for placeId: String) -> PlaceNote? {
        return placeNotes[placeId]
    }

    /// Resets all notes data (used during logout).
    func resetAllData() {
        placeNotes.removeAll()
    }
}
