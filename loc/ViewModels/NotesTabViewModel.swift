//
//  NotesTabViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Manages place notes with proper MVVM separation
//  Data-Driven: Receives place data via setPlace() instead of observing ViewModels
//

import Foundation
import Combine
import UIKit

@MainActor
class NotesTabViewModel: ObservableObject {
    // MARK: - Published State
    @Published var place: DetailPlace?
    @Published var placeNote: PlaceNote?
    @Published var noteText: String = ""
    @Published var linkText: String = ""
    @Published var isEditing: Bool = false
    @Published var showingDeleteAlert: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // MARK: - Dependencies (Services only)
    private let userService: UserService
    private var currentUserId: String?

    // MARK: - Callbacks (replaces ViewModel mutations)
    /// Called when a note is saved - allows parent to sync with ProfileViewModel
    var onNoteSaved: ((_ placeId: String, _ note: PlaceNote?) -> Void)?
    /// Called when a note is deleted - allows parent to sync with ProfileViewModel
    var onNoteDeleted: ((_ placeId: String) -> Void)?

    // MARK: - Initialization
    init(userSession: UserSession) {
        self.userService = ServiceContainer.shared.userService
        self.currentUserId = userSession.currentUserId
    }

    // MARK: - Data-Driven Updates

    /// Called by parent when the selected place changes
    func setPlace(_ place: DetailPlace?) {
        self.place = place
        if let place = place {
            loadNote(for: place.id.uuidString)
        } else {
            // Clear state when no place
            placeNote = nil
            noteText = ""
            linkText = ""
            isEditing = false
        }
    }

    /// Called by parent when notes are updated externally (e.g., from ProfileViewModel sync)
    func setNote(_ note: PlaceNote?) {
        self.placeNote = note
        if !isEditing {
            loadExistingNoteToFields()
        }
    }
    
    // MARK: - Computed Properties
    var hasExistingNote: Bool {
        placeNote?.hasContent ?? false
    }
    
    var saveButtonTitle: String {
        if isEditing {
            return "Save"
        } else if hasExistingNote {
            return "Edit"
        } else {
            return "Add Note"
        }
    }
    
    // MARK: - Actions
    func toggleEditing() {
        if isEditing {
            saveNote()
        } else {
            loadExistingNoteToFields()
            isEditing = true
        }
    }
    
    func saveNote() {
        guard let placeId = place?.id.uuidString,
              let userId = currentUserId else { return }

        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = linkText.trimmingCharacters(in: .whitespacesAndNewlines)

        let note = PlaceNote(
            placeId: placeId,
            userId: userId,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            link: trimmedLink.isEmpty ? nil : trimmedLink
        )

        userService.savePlaceNote(note: note) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.isEditing = false
                    self?.placeNote = note
                    // Notify parent to sync with ProfileViewModel
                    self?.onNoteSaved?(placeId, note)
                } else if let error = error {
                    self?.error = error
                    print("❌ Error saving place note: \(error.localizedDescription)")
                }
            }
        }
    }

    func deleteNote() {
        guard let placeId = place?.id.uuidString,
              let userId = currentUserId else { return }

        userService.deletePlaceNote(userId: userId, placeId: placeId) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.noteText = ""
                    self?.linkText = ""
                    self?.isEditing = false
                    self?.placeNote = nil
                    // Notify parent to sync with ProfileViewModel
                    self?.onNoteDeleted?(placeId)
                } else if let error = error {
                    self?.error = error
                    print("❌ Error deleting place note: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func showDeleteAlert() {
        showingDeleteAlert = true
    }
    
    /// Prepare fields for editing (called when sheet appears)
    func prepareForEditing() {
        loadExistingNoteToFields()
    }
    
    /// Cancel editing without saving (revert to original values)
    func cancelEditing() {
        loadExistingNoteToFields()
        isEditing = false
    }
    
    /// Opens the link associated with the note
    func openLink() {
        guard let link = placeNote?.link,
              !link.isEmpty,
              let url = URL(string: link) else { return }
        UIApplication.shared.open(url)
    }
    
    // MARK: - Private Helpers
    private func loadNote(for placeId: String) {
        guard let userId = currentUserId else { return }

        isLoading = true

        userService.fetchPlaceNote(userId: userId, placeId: placeId) { [weak self] placeNote, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let placeNote = placeNote {
                    self?.placeNote = placeNote
                    self?.loadExistingNoteToFields()
                    // Notify parent to sync with ProfileViewModel
                    self?.onNoteSaved?(placeId, placeNote)
                } else if let error = error {
                    self?.error = error
                    print("❌ Error loading place note: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadExistingNoteToFields() {
        if let placeNote = placeNote {
            noteText = placeNote.note ?? ""
            linkText = placeNote.link ?? ""
        } else {
            noteText = ""
            linkText = ""
        }
    }
}

