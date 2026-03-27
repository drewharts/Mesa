//
//  CategoryCorrectionViewModel.swift
//  loc
//
//  Handles business logic for the category correction sheet.
//

import Foundation

@MainActor
class CategoryCorrectionViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedCategory: String?
    @Published var isSaving: Bool = false
    @Published var didComplete: Bool = false
    @Published var errorMessage: String?

    private let placeService = ServiceContainer.shared.placeService
    private let placeId: String
    let currentCategory: String?
    let hasCorrectionOverride: Bool

    /// Creates a CategoryCorrectionViewModel for a given place.
    init(placeId: String, currentCategory: String?, hasCorrectionOverride: Bool) {
        self.placeId = placeId
        self.currentCategory = currentCategory
        self.hasCorrectionOverride = hasCorrectionOverride
        self.selectedCategory = currentCategory
    }

    /// Grouped types filtered by the current search text.
    var filteredGroups: [(section: String, types: [String])] {
        if searchText.isEmpty {
            return PlaceTypes.groupedTypes
        }
        let query = searchText.lowercased()
        return PlaceTypes.groupedTypes.compactMap { group in
            let filtered = group.types.filter { $0.lowercased().contains(query) }
            return filtered.isEmpty ? nil : (section: group.section, types: filtered)
        }
    }

    /// Selects a category from the picker.
    func selectCategory(_ category: String) {
        selectedCategory = category
    }

    /// Whether the save button should be enabled.
    var canSave: Bool {
        guard let selected = selectedCategory else { return false }
        return selected != currentCategory
    }

    /// Saves the corrected category to the database.
    func save() async {
        guard let category = selectedCategory else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await placeService.updatePlaceCorrectedCategory(placeId: placeId, category: category)
            didComplete = true
        } catch {
            errorMessage = "Failed to save. Please try again."
        }
        isSaving = false
    }

    /// Clears the correction, reverting to the auto-derived category.
    func clearCorrection() async {
        isSaving = true
        errorMessage = nil
        do {
            try await placeService.updatePlaceCorrectedCategory(placeId: placeId, category: nil)
            selectedCategory = nil
            didComplete = true
        } catch {
            errorMessage = "Failed to reset. Please try again."
        }
        isSaving = false
    }
}
