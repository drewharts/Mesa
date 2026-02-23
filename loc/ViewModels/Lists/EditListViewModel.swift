//
//  EditListViewModel.swift
//  loc
//
//  ViewModel for the Edit List sheet, handling name and description updates.
//

import Foundation

@MainActor
class EditListViewModel: ObservableObject {
    @Published var name: String
    @Published var descriptionText: String
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let listId: String
    private let originalName: String
    private let originalDescription: String
    private let placeListService: PlaceListService

    init(listId: String, currentName: String, currentDescription: String?) {
        self.listId = listId
        self.name = currentName
        self.descriptionText = currentDescription ?? ""
        self.originalName = currentName
        self.originalDescription = currentDescription ?? ""
        self.placeListService = .shared
    }

    /// Whether the user has changed the name or description from their original values.
    var hasChanges: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespaces)
        return trimmedName != originalName || trimmedDescription != originalDescription
    }

    /// Whether the current name is valid (non-empty after trimming).
    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Saves changed fields to the database, returning true on success.
    func save() async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            errorMessage = "List name cannot be empty"
            return false
        }

        isSaving = true
        errorMessage = nil

        do {
            if trimmedName != originalName {
                try await placeListService.updateListName(listId: listId, name: trimmedName)
            }
            if trimmedDescription != originalDescription {
                let newDescription: String? = trimmedDescription.isEmpty ? nil : trimmedDescription
                try await placeListService.updateListDescription(listId: listId, description: newDescription)
            }
            isSaving = false
            return true
        } catch {
            errorMessage = "Failed to save changes"
            isSaving = false
            return false
        }
    }
}
