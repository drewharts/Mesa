//
//  TikTokPlaceCorrectionSheet.swift
//  loc
//
//  Single Responsibility: Allow user to search and select the correct place for a TikTok
//  MVVM: Uses PlaceSearchService for search, ProfileViewModel for updating association

import SwiftUI

struct TikTokPlaceCorrectionSheet: View {
    let placeId: String
    let placeName: String
    let externalPlaceId: String?

    /// Callback when place is successfully changed - passes the resolved DetailPlace
    var onPlaceChanged: ((DetailPlace) -> Void)?

    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var searchResults: [MesaPlaceSuggestion] = []
    @State private var isSearching = false
    @State private var isUpdating = false
    @State private var errorMessage: String?

    private let searchService = PlaceSearchService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                currentPlaceHeader
                searchSection
                searchResultsList
            }
            .navigationTitle("Change Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isUpdating)
            .overlay {
                if isUpdating {
                    updatingOverlay
                }
            }
        }
    }

    // MARK: - Current Place Header

    private var currentPlaceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Place")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(placeName)
                        .font(.headline)
                        .lineLimit(2)

                    Text("Search below to find the correct place")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Search Section

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search for correct place")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 16)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search places...", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onChange(of: searchText) { _, newValue in
                        performSearch(query: newValue)
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List {
            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(searchResults, id: \.id) { suggestion in
                    Button {
                        selectPlace(suggestion)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.name)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                if let address = suggestion.address {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Updating Overlay

    private var updatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Updating place...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemGray2))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil

        searchService.searchPlaces(
            query: query,
            onResultsUpdated: { results in
                self.searchResults = results
                self.isSearching = false
            },
            onError: { error in
                self.errorMessage = error
                self.isSearching = false
            }
        )
    }

    /// Selects a suggestion, ensures the place exists in the DB, then updates the TikTok association
    private func selectPlace(_ suggestion: MesaPlaceSuggestion) {
        guard let extPlaceId = externalPlaceId else {
            errorMessage = "Cannot update: missing external place reference"
            return
        }

        isUpdating = true
        errorMessage = nil

        // Get full place details first
        searchService.selectSuggestion(
            suggestion,
            onError: { error in
                self.isUpdating = false
                self.errorMessage = "Failed to load place details: \(error)"
            }
        ) { detailPlace in
            Task {
                do {
                    // Upsert into places table so the FK constraint is satisfied
                    try await SupabasePlaceService.shared.ensurePlaceExists(place: detailPlace)

                    let newPlaceId = detailPlace.id.uuidString
                    await profile.updateTikTokPlaceById(
                        externalPlaceId: extPlaceId,
                        newPlaceId: newPlaceId,
                        newPlaceName: detailPlace.name
                    )
                    await MainActor.run {
                        isUpdating = false
                        dismiss()
                        onPlaceChanged?(detailPlace)
                    }
                } catch {
                    await MainActor.run {
                        isUpdating = false
                        errorMessage = "Failed to save place: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
