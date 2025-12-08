//
//  AddCollaboratorSheet.swift
//  loc
//
//  SMART Component: Search and add collaborators to a list
//  Single Responsibility: Coordinate user search and add flow
//

import SwiftUI

struct AddCollaboratorSheet: View {
    @ObservedObject var viewModel: AddCollaboratorViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                roleSelector
                Divider()
                searchResults
            }
            .navigationTitle("Add Collaborator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.error ?? "An error occurred")
            }
            .onChange(of: viewModel.addedSuccessfully) { _, success in
                if success {
                    handleSuccessfulAdd()
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search by name or email", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)
            
            if !viewModel.searchText.isEmpty {
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
    
    // MARK: - Role Selector
    
    private var roleSelector: some View {
        HStack {
            Text("Add as:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Role", selection: $viewModel.selectedRole) {
                ForEach(CollaboratorRole.allCases, id: \.self) { role in
                    Label(role.shortName, systemImage: role.icon)
                        .tag(role)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    // MARK: - Search Results
    
    @ViewBuilder
    private var searchResults: some View {
        if viewModel.isSearching {
            loadingView
        } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
            emptyResultsView
        } else if viewModel.searchResults.isEmpty {
            instructionsView
        } else {
            resultsList
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No users found")
                .font(.headline)
            
            Text("Try a different name or email")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var instructionsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Search for users")
                .font(.headline)
            
            Text("Enter a name or email to find people to add")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsList: some View {
        List {
            ForEach(viewModel.searchResults) { user in
                UserSearchRow(
                    user: user,
                    selectedRole: viewModel.selectedRole,
                    isAdding: viewModel.isAdding,
                    onAdd: {
                        Task {
                            await viewModel.addCollaborator(user)
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func handleSuccessfulAdd() {
        // Optional: Show brief success feedback before allowing another add
        // For now, just reset the success state so user can add more
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.resetSuccessState()
        }
    }
}

// MARK: - Preview

#Preview {
    AddCollaboratorSheet(
        viewModel: AddCollaboratorViewModel(
            listId: "test-list",
            currentUserId: "current-user",
            existingCollaboratorIds: []
        )
    )
}

