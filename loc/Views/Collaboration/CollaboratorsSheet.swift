//
//  CollaboratorsSheet.swift
//  loc
//
//  SMART Component: Manages collaborators for a list
//  Single Responsibility: Coordinate collaborator management UI
//

import SwiftUI

struct CollaboratorsSheet: View {
    @ObservedObject var viewModel: CollaboratorListViewModel
    @State private var showAddSheet = false
    @Environment(\.dismiss) private var dismiss
    
    // Needed for creating AddCollaboratorViewModel
    let listId: String
    let currentUserId: String
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Collaborators")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showAddSheet) {
                    addCollaboratorSheet
                }
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
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.hasCollaborators {
            collaboratorList
        } else {
            emptyState
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading collaborators...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var collaboratorList: some View {
        List {
            Section {
                ForEach(viewModel.collaborators) { collaborator in
                    CollaboratorRow(
                        collaborator: collaborator,
                        isOwner: viewModel.canManageCollaborators,
                        onRemove: {
                            Task { await viewModel.removeCollaborator(collaborator) }
                        },
                        onRoleChange: { newRole in
                            Task { await viewModel.updateRole(collaborator, to: newRole) }
                        }
                    )
                }
            } header: {
                Text("\(viewModel.collaboratorCount) collaborator\(viewModel.collaboratorCount == 1 ? "" : "s")")
            } footer: {
                if viewModel.canManageCollaborators {
                    Text("Editors can add and remove places. Viewers can only view the list.")
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No collaborators yet")
                .font(.headline)
            
            if viewModel.canManageCollaborators {
                Text("Add people to collaborate on this list")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Collaborator", systemImage: "person.badge.plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        
        if viewModel.canManageCollaborators {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
    }
    
    // MARK: - Add Sheet Factory
    
    private var addCollaboratorSheet: some View {
        let addVM = AddCollaboratorViewModel(
            listId: listId,
            currentUserId: currentUserId,
            existingCollaboratorIds: viewModel.existingCollaboratorIds
        )
        
        // Wire up callback to notify parent when collaborator is added
        addVM.onCollaboratorAdded = { [weak viewModel] collaborator in
            viewModel?.collaboratorAdded(collaborator)
        }
        
        return AddCollaboratorSheet(viewModel: addVM)
    }
}

// MARK: - Preview

#Preview {
    CollaboratorsSheet(
        viewModel: CollaboratorListViewModel(
            listId: "test-list",
            isOwner: true
        ),
        listId: "test-list",
        currentUserId: "current-user"
    )
}

