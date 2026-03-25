//
//  TripCollaboratorsViewModel.swift
//  loc
//
//  ViewModel for managing collaborators within a trip
//  Single Responsibility: Search, add, and remove trip collaborators
//

import Foundation
import Combine

@MainActor
class TripCollaboratorsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var searchText = ""
    @Published private(set) var searchResults: [ProfileData] = []
    @Published private(set) var isSearching = false
    @Published private(set) var collaborators: [LightweightCollaborator] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published var showError = false

    // MARK: - Child ViewModels

    let inviteViewModel: TripInviteViewModel

    // MARK: - Dependencies

    private let tripCollaborationService = ServiceContainer.shared.tripCollaborationService
    private let userService = ServiceContainer.shared.userService

    // MARK: - Properties

    private let tripId: String
    private let currentUserId: String
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private var existingCollaboratorIds: Set<String> {
        Set(collaborators.map(\.userId))
    }

    // MARK: - Initialization

    init(tripId: String, currentUserId: String, tripName: String, currentUserName: String) {
        self.tripId = tripId
        self.currentUserId = currentUserId
        self.inviteViewModel = TripInviteViewModel(
            tripId: tripId,
            currentUserId: currentUserId,
            tripName: tripName,
            currentUserName: currentUserName
        )
        setupSearchPipeline()
        forwardChildObjectWillChange()
    }

    /// Forwards child ViewModel's objectWillChange so the parent view re-renders.
    private func forwardChildObjectWillChange() {
        inviteViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    /// Sets up debounced search for contributors.
    private func setupSearchPipeline() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    // MARK: - Load

    /// Fetches current collaborators for the trip.
    func loadCollaborators() async {
        isLoading = true
        do {
            collaborators = try await tripCollaborationService.fetchCollaborators(tripId: tripId)
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    // MARK: - Search

    /// Performs a debounced user search.
    private func performSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            isSearching = true
            do {
                let users: [User] = try await withCheckedThrowingContinuation { continuation in
                    userService.searchUsers(query: trimmed) { users, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: users ?? [])
                        }
                    }
                }

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
                print("[TripCollaboratorsVM] Search failed: \(error)")
            }
            isSearching = false
        }
    }

    // MARK: - Add

    /// Adds a user as a trip collaborator.
    func addCollaborator(_ user: ProfileData) async {
        do {
            try await tripCollaborationService.addCollaborator(
                tripId: tripId,
                userId: user.id,
                role: .editor,
                addedBy: currentUserId
            )

            let newCollaborator = LightweightCollaborator(
                id: UUID().uuidString,
                userId: user.id,
                role: CollaboratorRole.editor.rawValue,
                userName: user.fullName,
                profilePhotoUrl: user.profilePhotoURL?.absoluteString
            )
            collaborators.append(newCollaborator)
            searchResults.removeAll { $0.id == user.id }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Remove

    /// Removes a collaborator from the trip.
    func removeCollaborator(_ collaborator: LightweightCollaborator) async {
        do {
            try await tripCollaborationService.removeCollaborator(collaboratorId: collaborator.id)
            collaborators.removeAll { $0.id == collaborator.id }
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }

    /// Clears search state.
    func clearSearch() {
        searchText = ""
        searchResults = []
    }
}
