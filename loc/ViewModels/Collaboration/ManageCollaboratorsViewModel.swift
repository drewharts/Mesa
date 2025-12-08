//
//  ManageCollaboratorsViewModel.swift
//  loc
//
//  ViewModel for managing collaborators - search, add, and remove in one place
//  Single Responsibility: State management for collaborator management
//

import Foundation
import Combine

@MainActor
class ManageCollaboratorsViewModel: ObservableObject {
    // MARK: - Published State
    
    // Search state
    @Published var searchText = ""
    @Published private(set) var searchResults: [ProfileData] = []
    @Published private(set) var isSearching = false
    
    // Collaborators state
    @Published private(set) var collaborators: [LightweightCollaborator] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isAdding = false
    
    // Error state
    @Published private(set) var error: String?
    @Published var showError = false
    
    // MARK: - Dependencies
    private let collaborationService: CollaborationService
    private let userService: UserService
    private let listId: String
    private let currentUserId: String
    
    // MARK: - Private
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var hasCollaborators: Bool { !collaborators.isEmpty }
    var collaboratorCount: Int { collaborators.count }
    var isShowingSearchResults: Bool { !searchText.isEmpty && !searchResults.isEmpty }
    
    private var existingCollaboratorIds: Set<String> {
        Set(collaborators.map(\.userId))
    }
    
    // MARK: - Initialization
    
    init(
        listId: String,
        currentUserId: String,
        collaborationService: CollaborationService = .shared,
        userService: UserService = .shared
    ) {
        self.listId = listId
        self.currentUserId = currentUserId
        self.collaborationService = collaborationService
        self.userService = userService
        
        setupSearchPipeline()
    }
    
    // MARK: - Setup
    
    private func setupSearchPipeline() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Collaborators
    
    func loadCollaborators() async {
        isLoading = true
        error = nil
        
        do {
            collaborators = try await collaborationService.fetchCollaborators(listId: listId)
            print("✅ [ManageCollaboratorsVM] Loaded \(collaborators.count) collaborators")
        } catch {
            self.error = error.localizedDescription
            self.showError = true
            print("❌ [ManageCollaboratorsVM] Failed to load: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Search
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            isSearching = true
            await searchUsers(query: trimmed)
            isSearching = false
        }
    }
    
    private func searchUsers(query: String) async {
        do {
            let users: [User] = try await withCheckedThrowingContinuation { continuation in
                userService.searchUsers(query: query) { users, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: users ?? [])
                    }
                }
            }
            
            // Filter out current user and existing collaborators
            searchResults = users
                .filter { $0.id != currentUserId }
                .filter { !existingCollaboratorIds.contains($0.id) }
                .map { user in
                    ProfileData(
                        id: user.id,
                        firstName: user.firstName,
                        lastName: user.lastName,
                        email: user.email,
                        profilePhotoURL: user.profilePhotoURL,
                        phoneNumber: "",
                        fullNameLower: user.fullName.lowercased(),
                        fullName: user.fullName,
                        fcmToken: nil,
                        firebaseUid: nil,
                        supabaseUid: nil
                    )
                }
        } catch {
            print("❌ [ManageCollaboratorsVM] Search failed: \(error)")
        }
    }
    
    // MARK: - Add Collaborator
    
    func addCollaborator(_ user: ProfileData) async {
        isAdding = true
        error = nil
        
        do {
            try await collaborationService.addCollaborator(
                listId: listId,
                userId: user.id,
                role: .editor,
                addedBy: currentUserId
            )
            
            // Add to local collaborators list
            let newCollaborator = LightweightCollaborator(
                id: UUID().uuidString,
                userId: user.id,
                role: CollaboratorRole.editor.rawValue,
                userName: user.fullName,
                profilePhotoUrl: user.profilePhotoURL?.absoluteString
            )
            collaborators.append(newCollaborator)
            
            // Remove from search results
            searchResults.removeAll { $0.id == user.id }
            
            print("✅ [ManageCollaboratorsVM] Added \(user.fullName)")
            
        } catch let error as CollaborationError {
            self.error = error.localizedDescription
            self.showError = true
        } catch {
            self.error = "Failed to add collaborator"
            self.showError = true
        }
        
        isAdding = false
    }
    
    // MARK: - Remove Collaborator
    
    func removeCollaborator(_ collaborator: LightweightCollaborator) async {
        do {
            try await collaborationService.removeCollaborator(collaboratorId: collaborator.id)
            collaborators.removeAll { $0.id == collaborator.id }
            print("✅ [ManageCollaboratorsVM] Removed \(collaborator.displayName)")
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
    
    // MARK: - Helpers
    
    func clearSearch() {
        searchText = ""
        searchResults = []
    }
    
    func clearError() {
        error = nil
        showError = false
    }
}

