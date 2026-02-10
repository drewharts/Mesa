//
//  GoogleMapsImportViewModel.swift
//  loc
//
//  Created by Claude on 2/9/26.
//
//  SMART ViewModel: Coordinates the Google Maps list import flow.
//  Single Responsibility: Manages import phases and orchestrates child VMs.
//

import Foundation
import Combine

@MainActor
class GoogleMapsImportViewModel: ObservableObject {

    // MARK: - Published State

    @Published var importPhase: GoogleMapsImportPhase = .input
    @Published var urlText: String = ""
    @Published var errorMessage: String?
    @Published var suggestedListName: String?
    @Published var selectedListId: String?
    @Published var selectedListName: String?

    // MARK: - Child ViewModel & Extractor

    let reviewViewModel = GoogleMapsImportReviewViewModel()
    let extractor = GoogleMapsListExtractor()

    // MARK: - Dependencies

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    /// Forwards child VM and extractor changes to parent for UI updates.
    init() {
        reviewViewModel.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        extractor.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    /// Returns whether the URL input is valid for processing.
    var canProcess: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && (
            trimmed.contains("google.com/maps") ||
            trimmed.contains("maps.app.goo.gl") ||
            trimmed.contains("goo.gl/maps")
        )
    }

    // MARK: - Public API

    /// Processes the entered Google Maps list URL: prepares the WebView, extracts places, then resolves them.
    func processURL() async {
        errorMessage = nil
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard canProcess else {
            errorMessage = "Please enter a valid Google Maps list link."
            return
        }

        // Prepare the WebView first so the UI can embed it
        extractor.prepareWebView()
        importPhase = .extracting

        // Brief delay to let SwiftUI embed the WebView in the view hierarchy.
        // The WebView needs to be in a real view hierarchy for proper JS execution.
        try? await Task.sleep(nanoseconds: 300_000_000)

        do {
            let result = try await extractor.loadAndExtract(from: trimmedURL)
            suggestedListName = result.listName

            guard !result.places.isEmpty else {
                errorMessage = "No places found in this list."
                importPhase = .input
                return
            }

            importPhase = .resolving
            await reviewViewModel.resolveAllPlaces(result.places)
            importPhase = .review
        } catch {
            errorMessage = error.localizedDescription
            importPhase = .input
        }
    }

    /// Starts the batch import of selected places to the chosen list.
    func startImport(userId: String) async {
        guard let listId = selectedListId else { return }

        importPhase = .importing
        _ = await reviewViewModel.performBatchImport(userId: userId, listId: listId)
        importPhase = .complete
    }

    /// Selects an existing list as the import destination.
    func selectList(id: String, name: String) {
        selectedListId = id
        selectedListName = name
    }

    /// Creates a new list and selects it as the import destination.
    func createAndSelectList(named name: String, profile: ProfileViewModel) async {
        let result = await profile.addNewPlaceList(named: name, city: "", emoji: "", image: "")
        if case .success(let list) = result {
            selectedListId = list.id.uuidString
            selectedListName = list.name
        }
    }

    /// Resets the import flow to start over.
    func reset() {
        importPhase = .input
        urlText = ""
        errorMessage = nil
        suggestedListName = nil
        selectedListId = nil
        selectedListName = nil
    }
}
