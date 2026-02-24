//
//  CreateTripViewModel.swift
//  loc
//
//  ViewModel for the trip creation wizard flow
//  Single Responsibility: State machine for multi-step trip creation
//

import Foundation
import Combine

/// Represents each step of the trip creation wizard.
enum CreateTripStep: Equatable {
    case name
    case dates
    case contributors
    case creating
    case completed(tripId: String)
    case failed(message: String)

    static func == (lhs: CreateTripStep, rhs: CreateTripStep) -> Bool {
        switch (lhs, rhs) {
        case (.name, .name), (.dates, .dates), (.contributors, .contributors),
             (.creating, .creating):
            return true
        case (.completed(let l), .completed(let r)):
            return l == r
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }
}

@MainActor
class CreateTripViewModel: ObservableObject {
    // MARK: - Published State

    @Published var currentStep: CreateTripStep = .name
    @Published var tripName: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    // Contributors
    @Published var selectedContributors: [ProfileData] = []
    @Published var contributorSearchText: String = ""
    @Published private(set) var contributorSearchResults: [ProfileData] = []
    @Published private(set) var isSearchingContributors = false

    // MARK: - Dependencies

    private let tripService = ServiceContainer.shared.tripService
    private let tripCollaborationService = ServiceContainer.shared.tripCollaborationService
    private let userService = ServiceContainer.shared.userService

    // MARK: - Private

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupContributorSearchPipeline()
    }

    // MARK: - Navigation

    /// Advances to the next step in the wizard.
    func nextStep() {
        switch currentStep {
        case .name:
            currentStep = .dates
        case .dates:
            currentStep = .contributors
        default:
            break
        }
    }

    /// Returns to the previous step in the wizard.
    func previousStep() {
        switch currentStep {
        case .dates:
            currentStep = .name
        case .contributors:
            currentStep = .dates
        default:
            break
        }
    }

    // MARK: - Validation

    /// Whether the current step's input is valid for proceeding.
    var canProceed: Bool {
        switch currentStep {
        case .name:
            return !tripName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .dates:
            return endDate >= startDate
        case .contributors:
            return true
        default:
            return false
        }
    }

    // MARK: - Trip Creation

    /// Orchestrates trip creation: insert trip, then add collaborators.
    func createTrip(ownerId: String) async {
        let trimmedName = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            currentStep = .failed(message: "Please enter a trip name.")
            return
        }

        currentStep = .creating

        do {
            // 1. Create the trip
            let trip = try await tripService.createTrip(
                name: trimmedName,
                ownerId: ownerId,
                startDate: startDate,
                endDate: endDate
            )

            // 2. Add collaborators
            for contributor in selectedContributors {
                try? await tripCollaborationService.addCollaborator(
                    tripId: trip.id,
                    userId: contributor.id,
                    role: .editor,
                    addedBy: ownerId
                )
            }

            currentStep = .completed(tripId: trip.id)
        } catch {
            currentStep = .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Contributor Search

    /// Sets up debounced search pipeline for contributor search.
    private func setupContributorSearchPipeline() {
        $contributorSearchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performContributorSearch(query: query)
            }
            .store(in: &cancellables)
    }

    /// Performs a user search for potential contributors.
    private func performContributorSearch(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            contributorSearchResults = []
            return
        }

        let selectedIds = Set(selectedContributors.map(\.id))

        searchTask = Task {
            isSearchingContributors = true
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

                contributorSearchResults = users
                    .filter { !selectedIds.contains($0.id) }
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
                print("[CreateTripVM] Contributor search failed: \(error)")
            }
            isSearchingContributors = false
        }
    }

    /// Adds a user to the selected contributors list.
    func selectContributor(_ user: ProfileData) {
        guard !selectedContributors.contains(where: { $0.id == user.id }) else { return }
        selectedContributors.append(user)
        contributorSearchResults.removeAll { $0.id == user.id }
    }

    /// Removes a user from the selected contributors list.
    func removeContributor(_ user: ProfileData) {
        selectedContributors.removeAll { $0.id == user.id }
    }

    /// Clears the contributor search state.
    func clearContributorSearch() {
        contributorSearchText = ""
        contributorSearchResults = []
    }

    // MARK: - Reset

    /// Resets the wizard to its initial state.
    func reset() {
        currentStep = .name
        tripName = ""
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        selectedContributors = []
        contributorSearchText = ""
        contributorSearchResults = []
    }
}
