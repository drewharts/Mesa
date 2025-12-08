//
//  AddCollaboratorViewModel.swift
//  loc
//
//  ViewModel for searching and adding collaborators
//  Single Responsibility: User search + add collaborator flow
//

import Foundation
import Combine

@MainActor
class AddCollaboratorViewModel: ObservableObject {
    // MARK: - Published State
    @Published var searchText = ""
    @Published private(set) var searchResults: [ProfileData] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isAdding = false
    @Published private(set) var error: String?
    @Published var showError = false
    @Published var selectedRole: CollaboratorRole = .editor
    
    // MARK: - Success State
    @Published var addedSuccessfully = false
    @Published var lastAddedUser: ProfileData?
    
    // MARK: - Dependencies
    private let userService: UserService
    private let collaborationService: CollaborationService
    private let listId: String
    private let currentUserId: String
    private var existingCollaboratorIds: Set<String>
    
    // MARK: - Callbacks
    var onCollaboratorAdded: ((LightweightCollaborator) -> Void)?
    
    // MARK: - Private
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        listId: String,
        currentUserId: String,
        existingCollaboratorIds: [String],
        userService: UserService = .shared,
        collaborationService: CollaborationService = .shared
    ) {
        self.listId = listId
        self.currentUserId = currentUserId
        self.existingCollaboratorIds = Set(existingCollaboratorIds)
        self.userService = userService
        self.collaborationService = collaborationService
        
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
    
    // MARK: - Search
    
    private func performSearch(query: String) {
        // Cancel any existing search
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
            let users = try await withCheckedThrowingContinuation { continuation in
                userService.searchUsers(query: query) { users, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: users ?? [])
                    }
                }
            }
            
            // Filter results
            searchResults = filterSearchResults(users)
            
        } catch {
            print("❌ [AddCollaboratorVM] Search failed: \(error)")
            // Don't show error for search failures - just show empty results
        }
    }
    
    private func filterSearchResults(_ users: [User]) -> [ProfileData] {
        users
            .filter { $0.id != currentUserId }  // Exclude self
            .filter { !existingCollaboratorIds.contains($0.id) }  // Exclude existing collaborators
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
    }
    
    // MARK: - Add Collaborator
    
    func addCollaborator(_ user: ProfileData) async -> Bool {
        isAdding = true
        error = nil
        addedSuccessfully = false
        
        do {
            try await collaborationService.addCollaborator(
                listId: listId,
                userId: user.id,
                role: selectedRole,
                addedBy: currentUserId
            )
            
            // Create lightweight collaborator for callback
            let newCollaborator = LightweightCollaborator(
                id: UUID().uuidString, // Temporary - will be replaced on refresh
                userId: user.id,
                role: selectedRole.rawValue,
                userName: user.fullName,
                profilePhotoUrl: user.profilePhotoURL
            )
            
            // Update local state
            existingCollaboratorIds.insert(user.id)
            searchResults.removeAll { $0.id == user.id }
            
            // Notify parent
            onCollaboratorAdded?(newCollaborator)
            
            // Update success state
            lastAddedUser = user
            addedSuccessfully = true
            isAdding = false
            
            print("✅ [AddCollaboratorVM] Added \(user.fullName) as \(selectedRole.rawValue)")
            return true
            
        } catch let error as CollaborationError {
            self.error = error.localizedDescription
            self.showError = true
            isAdding = false
            return false
            
        } catch {
            self.error = "Failed to add collaborator"
            self.showError = true
            isAdding = false
            return false
        }
    }
    
    // MARK: - Helpers
    
    func clearError() {
        error = nil
        showError = false
    }
    
    func clearSearch() {
        searchText = ""
        searchResults = []
    }
    
    func resetSuccessState() {
        addedSuccessfully = false
        lastAddedUser = nil
    }
}

