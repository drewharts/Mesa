//
//  ManageTripCollaboratorsSheet.swift
//  loc
//
//  Sheet for managing trip collaborators (search, add, remove)
//

import SwiftUI

/// Sheet for searching and managing trip collaborators.
struct ManageTripCollaboratorsSheet: View {
    @StateObject private var viewModel: TripCollaboratorsViewModel
    @Environment(\.dismiss) private var dismiss

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    init(tripId: String, currentUserId: String) {
        _viewModel = StateObject(wrappedValue: TripCollaboratorsViewModel(
            tripId: tripId,
            currentUserId: currentUserId
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Current collaborators
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        } else if !viewModel.collaborators.isEmpty {
                            collaboratorsList
                        }

                        // Search results
                        if viewModel.isSearching {
                            ProgressView("Searching...")
                                .padding()
                        } else if !viewModel.searchResults.isEmpty {
                            searchResultsList
                        }
                    }
                }
            }
            .navigationTitle("Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.error ?? "Something went wrong")
            }
            .task {
                await viewModel.loadCollaborators()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search by name...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    // MARK: - Collaborators List

    private var collaboratorsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Current Collaborators")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)

            ForEach(viewModel.collaborators) { collaborator in
                HStack(spacing: 12) {
                    if let urlString = collaborator.profilePhotoUrl,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.gray.opacity(0.5))
                    }

                    Text(collaborator.displayName)
                        .font(.body)

                    Spacer()

                    Button(role: .destructive) {
                        Task {
                            await viewModel.removeCollaborator(collaborator)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add People")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)

            ForEach(viewModel.searchResults) { user in
                Button {
                    Task {
                        await viewModel.addCollaborator(user)
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let url = user.profilePhotoURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.gray.opacity(0.5))
                        }

                        Text(user.fullName)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "plus.circle")
                            .foregroundColor(mesaCharcoal)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
