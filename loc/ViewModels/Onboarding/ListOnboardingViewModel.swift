//
//  ListOnboardingViewModel.swift
//  loc
//
//  Thin coordinator wrapping GoogleMapsImportViewModel for the onboarding flow.
//

import Foundation
import Combine

@MainActor
class ListOnboardingViewModel: ObservableObject {

    // MARK: - Child ViewModel (Composition)

    var importViewModel = GoogleMapsImportViewModel()

    // MARK: - Combine Forwarding

    private var cancellables = Set<AnyCancellable>()

    init() {
        importViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Convenience Computed Properties

    /// Whether the import has resolved at least one place.
    var hasResults: Bool {
        !importViewModel.resolvedPlaces.isEmpty
    }

    /// Whether the URL field contains a valid Google Maps link.
    var canExtract: Bool {
        importViewModel.isValidGoogleMapsURL(importViewModel.url)
    }

    /// Whether the user can create a list (has results and a non-empty name).
    var canCreateList: Bool {
        hasResults && !importViewModel.listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Delegated Actions

    /// Kicks off the two-phase extract + resolve flow.
    func startImport() async {
        await importViewModel.extractPlaces()
    }

    /// Creates a new list with all resolved places.
    func createList(userId: String) async {
        await importViewModel.createListWithPlaces(userId: userId)
    }

    /// Resets the entire import flow back to the initial state.
    func reset() {
        importViewModel.reset()
    }
}
