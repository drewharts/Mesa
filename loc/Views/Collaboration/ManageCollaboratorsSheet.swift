//
//  ManageCollaboratorsSheet.swift
//  loc
//
//  Combined view for searching, adding, and managing collaborators
//  Single Responsibility: UI for collaborator management
//

import SwiftUI

struct ManageCollaboratorsSheet: View {
    @StateObject private var viewModel: ManageCollaboratorsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    
    init(listId: String, currentUserId: String) {
        _viewModel = StateObject(wrappedValue: ManageCollaboratorsViewModel(
            listId: listId,
            currentUserId: currentUserId
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                content
            }
            .navigationTitle("Collaborators")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.error ?? "An error occurred")
            }
        }
        .task {
            await viewModel.loadCollaborators()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search to add people...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)
            
            if viewModel.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingView
        } else {
            collaboratorsList
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var collaboratorsList: some View {
        List {
            // Search results section (only when searching)
            if viewModel.isShowingSearchResults {
                Section {
                    ForEach(viewModel.searchResults) { user in
                        searchResultRow(user: user)
                    }
                } header: {
                    Text("Add People")
                }
            }
            
            // Existing collaborators section
            Section {
                if viewModel.hasCollaborators {
                    ForEach(viewModel.collaborators) { collaborator in
                        collaboratorRow(collaborator: collaborator)
                    }
                } else {
                    emptyCollaboratorsView
                }
            } header: {
                if viewModel.hasCollaborators {
                    Text("Collaborators (\(viewModel.collaboratorCount))")
                } else {
                    Text("Collaborators")
                }
            } footer: {
                Text("Collaborators can add and remove places from this list.")
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Search Result Row
    
    private func searchResultRow(user: ProfileData) -> some View {
        HStack(spacing: 12) {
            // Profile image
            AsyncImage(url: user.profilePhotoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(user.fullName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.body)
                    .fontWeight(.medium)
                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Add button
            Button {
                Task { await viewModel.addCollaborator(user) }
            } label: {
                if viewModel.isAdding {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 60, height: 28)
                } else {
                    Text("Add")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 28)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .disabled(viewModel.isAdding)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Collaborator Row
    
    private func collaboratorRow(collaborator: LightweightCollaborator) -> some View {
        HStack(spacing: 12) {
            // Profile image
            AsyncImage(url: URL(string: collaborator.profilePhotoUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Text(collaborator.displayName.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Name
            Text(collaborator.displayName)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            // Remove menu
            Menu {
                Button(role: .destructive) {
                    Task { await viewModel.removeCollaborator(collaborator) }
                } label: {
                    Label("Remove", systemImage: "person.badge.minus")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Empty State
    
    private var emptyCollaboratorsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No collaborators yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Search above to add people")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
    }
}

// MARK: - Preview

#Preview {
    ManageCollaboratorsSheet(
        listId: "test-list",
        currentUserId: "current-user"
    )
}

