//
//  ListSettingsViewModel.swift
//  loc
//
//  ViewModel for managing list settings, including privacy toggle.
//

import Foundation

@MainActor
class ListSettingsViewModel: ObservableObject {
    @Published var isPublic: Bool
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let listId: String
    private let placeListService: PlaceListService

    init(listId: String, initialIsPublic: Bool) {
        self.listId = listId
        self.isPublic = initialIsPublic
        self.placeListService = .shared
    }

    /// Saves the privacy setting to the database.
    func savePrivacySetting() async -> Bool {
        isSaving = true
        errorMessage = nil

        do {
            try await placeListService.updateListPrivacy(listId: listId, isPublic: isPublic)
            isSaving = false
            return true
        } catch {
            errorMessage = "Failed to save privacy setting"
            isSaving = false
            return false
        }
    }
}
