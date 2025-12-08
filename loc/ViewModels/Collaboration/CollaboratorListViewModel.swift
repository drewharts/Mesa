//
//  CollaboratorListViewModel.swift
//  loc
//
//  ViewModel for managing collaborators on a single list
//  Single Responsibility: State management for collaborator list display and actions
//

import Foundation

@MainActor
class CollaboratorListViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var collaborators: [LightweightCollaborator] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published var showError = false
    
    // MARK: - Dependencies
    private let collaborationService: CollaborationService
    private let listId: String
    private let isOwner: Bool
    
    // MARK: - Initialization
    
    init(
        listId: String,
        isOwner: Bool,
        collaborationService: CollaborationService = .shared
    ) {
        self.listId = listId
        self.isOwner = isOwner
        self.collaborationService = collaborationService
    }
    
    // MARK: - Computed Properties
    
    var canManageCollaborators: Bool { isOwner }
    var hasCollaborators: Bool { !collaborators.isEmpty }
    var collaboratorCount: Int { collaborators.count }
    
    var existingCollaboratorIds: [String] {
        collaborators.map(\.userId)
    }
    
    // MARK: - Public Methods
    
    func loadCollaborators() async {
        isLoading = true
        error = nil
        
        do {
            collaborators = try await collaborationService.fetchCollaborators(listId: listId)
            print("✅ [CollaboratorListVM] Loaded \(collaborators.count) collaborators")
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            print("❌ [CollaboratorListVM] Failed to load: \(error)")
        }
        
        isLoading = false
    }
    
    func removeCollaborator(_ collaborator: LightweightCollaborator) async {
        guard isOwner else {
            error = "Only the list owner can remove collaborators"
            showError = true
            return
        }
        
        do {
            try await collaborationService.removeCollaborator(collaboratorId: collaborator.id)
            
            // Remove from local state
            collaborators.removeAll { $0.id == collaborator.id }
            print("✅ [CollaboratorListVM] Removed collaborator \(collaborator.displayName)")
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            print("❌ [CollaboratorListVM] Failed to remove: \(error)")
        }
    }
    
    func updateRole(_ collaborator: LightweightCollaborator, to newRole: CollaboratorRole) async {
        guard isOwner else {
            error = "Only the list owner can change roles"
            showError = true
            return
        }
        
        do {
            try await collaborationService.updateRole(
                collaboratorId: collaborator.id,
                newRole: newRole
            )
            
            // Refresh to get updated data
            await loadCollaborators()
            print("✅ [CollaboratorListVM] Updated role to \(newRole.rawValue)")
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            print("❌ [CollaboratorListVM] Failed to update role: \(error)")
        }
    }
    
    /// Called when AddCollaboratorViewModel successfully adds someone
    func collaboratorAdded(_ collaborator: LightweightCollaborator) {
        // Avoid duplicates
        guard !collaborators.contains(where: { $0.id == collaborator.id }) else { return }
        collaborators.append(collaborator)
    }
    
    func clearError() {
        error = nil
        showError = false
    }
}

