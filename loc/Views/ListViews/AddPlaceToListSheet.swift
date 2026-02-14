//
//  AddPlaceToListSheet.swift
//  loc
//
//  Single Responsibility: Display place search UI for adding a place to a specific list.
//  Creates its own ViewModel, receives only data (listId, userId).
//

import SwiftUI

struct AddPlaceToListSheet: View {
    let listId: String
    let listName: String
    let userId: String

    /// Callback when a place is successfully added - passes placeId and DetailPlace for optimistic cache update.
    var onPlaceAdded: ((String, DetailPlace) -> Void)?

    @StateObject private var viewModel: AddPlaceToListViewModel
    @Environment(\.dismiss) private var dismiss

    init(listId: String, listName: String, userId: String, onPlaceAdded: ((String, DetailPlace) -> Void)? = nil) {
        self.listId = listId
        self.listName = listName
        self.userId = userId
        self.onPlaceAdded = onPlaceAdded
        self._viewModel = StateObject(wrappedValue: AddPlaceToListViewModel(listId: listId, userId: userId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                listInfoHeader
                searchField
                searchResultsList
            }
            .navigationTitle("Add Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(viewModel.isAddingPlace)
            .overlay {
                if viewModel.isAddingPlace {
                    addingOverlay
                }
            }
            .onChange(of: viewModel.addedPlaceId) { _, newPlaceId in
                if let placeId = newPlaceId, let place = viewModel.addedPlace {
                    onPlaceAdded?(placeId, place)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    private var listInfoHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adding to")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "list.bullet")
                            .foregroundColor(.gray)
                            .font(.title3)
                    )

                Text(listName)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search for a place")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 16)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search places...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.search(query: newValue)
                    }

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }

                if viewModel.isSearching {
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

    private var searchResultsList: some View {
        List {
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }

            if let success = viewModel.successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .foregroundColor(.green)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            }

            if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty && !viewModel.isSearching {
                Text("No places found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.searchResults, id: \.id) { suggestion in
                    Button {
                        viewModel.selectAndAddPlace(suggestion)
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

                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var addingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Adding place...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemGray2))
            .cornerRadius(12)
        }
    }
}

#Preview {
    AddPlaceToListSheet(
        listId: "test-list-id",
        listName: "My Test List",
        userId: "test-user-id"
    )
}
