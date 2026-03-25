//
//  TripInviteViewModel.swift
//  loc
//
//  ViewModel for the SMS invite flow within trip collaborator management
//  Single Responsibility: Validate phone, create invitation, prepare SMS
//

import Foundation
import Combine

@MainActor
class TripInviteViewModel: ObservableObject {

    // MARK: - Published State

    @Published var phoneInput = ""
    @Published var isSending = false
    @Published var error: String?
    @Published var showError = false
    @Published var showMessageComposer = false
    @Published var pendingInvitations: [TripInvitation] = []

    /// Set before presenting the message composer.
    @Published private(set) var inviteMessage = ""
    @Published private(set) var recipientPhone = ""

    // MARK: - Dependencies

    private let invitationService = ServiceContainer.shared.tripInvitationService
    private let tripId: String
    private let currentUserId: String
    private let tripName: String
    private let currentUserName: String

    // MARK: - Initialization

    init(tripId: String, currentUserId: String, tripName: String, currentUserName: String) {
        self.tripId = tripId
        self.currentUserId = currentUserId
        self.tripName = tripName
        self.currentUserName = currentUserName
    }

    // MARK: - Prepare Invitation

    /// Validates phone input, creates a DB invitation record, and triggers the SMS composer.
    func prepareInvitation() async {
        let trimmed = phoneInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized = PhoneNumberNormalizer.normalize(trimmed, dialCode: "1") else {
            error = "Please enter a valid phone number."
            showError = true
            return
        }

        isSending = true
        do {
            let invitation = try await createInvitationRecord(phone: normalized)
            configureMessageComposer(invitation: invitation, phone: normalized)
        } catch {
            self.error = "Could not create invitation. They may already be invited."
            showError = true
        }
        isSending = false
    }

    /// Creates the invitation record in the database for the given phone number.
    private func createInvitationRecord(phone: String) async throws -> TripInvitation {
        try await invitationService.createInvitation(
            tripId: tripId,
            phone: phone,
            invitedBy: currentUserId
        )
    }

    /// Generates the invite URL, sets the message text, and presents the SMS composer.
    private func configureMessageComposer(invitation: TripInvitation, phone: String) {
        guard let url = invitationService.generateInviteURL(
            token: invitation.token,
            tripName: tripName,
            inviterName: currentUserName
        ) else {
            error = "Failed to generate invite link."
            showError = true
            return
        }

        recipientPhone = phone
        inviteMessage = "\(currentUserName) invited you to join the trip \"\(tripName)\" on Mesa! Tap to join: \(url.absoluteString)"
        pendingInvitations.append(invitation)
        phoneInput = ""
        showMessageComposer = true
    }

    // MARK: - Post-SMS Callbacks

    /// Called when the user successfully sends (or the composer is dismissed after sending).
    func confirmInvitationSent() {
        showMessageComposer = false
    }

    /// Called when the user cancels the SMS composer — revoke the last invitation.
    func cancelInvitation() {
        showMessageComposer = false
        guard let last = pendingInvitations.last else { return }
        pendingInvitations.removeAll { $0.id == last.id }
        Task {
            try? await invitationService.revokeInvitation(invitationId: last.id)
        }
    }

    // MARK: - Load Pending

    /// Fetches pending invitations for display.
    func loadPendingInvitations() async {
        do {
            pendingInvitations = try await invitationService.fetchPendingInvitations(tripId: tripId)
        } catch {
            print("[TripInviteVM] Failed to load pending invitations: \(error)")
        }
    }

    // MARK: - Revoke

    /// Revokes a specific pending invitation.
    func revokeInvitation(_ invitation: TripInvitation) async {
        do {
            try await invitationService.revokeInvitation(invitationId: invitation.id)
            pendingInvitations.removeAll { $0.id == invitation.id }
        } catch {
            self.error = "Failed to revoke invitation."
            showError = true
        }
    }
}
