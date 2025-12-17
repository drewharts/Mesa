//
//  NotesTabViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Manages place notes with proper MVVM separation
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
    
    // MARK: - Dependencies
    private let userService: UserService
    private let selectedPlaceVM: SelectedPlaceViewModel  // Temporary until fully refactored
    private let profileVM: ProfileViewModel  // Temporary for placeNotes dictionary
    
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String?
    
    // MARK: - Initialization
    init(userService: UserService,
         selectedPlaceVM: SelectedPlaceViewModel,
         profileVM: ProfileViewModel,
         userSession: UserSession) {
        self.userService = userService
        self.selectedPlaceVM = selectedPlaceVM
        self.profileVM = profileVM
        self.currentUserId = userSession.currentUserId
        
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe place changes
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                self?.place = place
                if let place = place {
                    self?.loadNote(for: place.id.uuidString)
                }
            }
            .store(in: &cancellables)
        
        // Observe note changes from ProfileViewModel
        profileVM.$placeNotes
            .sink { [weak self] notes in
                guard let self = self,
                      let placeId = self.place?.id.uuidString else { return }
                self.placeNote = notes[placeId]
                if !self.isEditing {
                    self.loadExistingNoteToFields()
                }
            }
            .store(in: &cancellables)
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
                    self?.profileVM.placeNotes[placeId] = note
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
                    self?.profileVM.placeNotes.removeValue(forKey: placeId)
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
                    self?.profileVM.placeNotes[placeId] = placeNote
                    self?.loadExistingNoteToFields()
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

