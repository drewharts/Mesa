//
//  ProfileAccountViewModel.swift
//  loc
//
//  Extracted from ProfileViewModel for account management functionality.
//

import SwiftUI

/// Manages account deletion flow for the current user's profile.
@MainActor
class ProfileAccountViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Shows the initial delete account warning (Step 1 of 2)
    @Published var showDeleteAccountWarning: Bool = false

    /// Shows the final delete confirmation (Step 2 of 2)
    @Published var showDeleteAccountConfirmation: Bool = false

    /// Indicates if account deletion is in progress
    @Published var isDeletingAccount: Bool = false

    /// Error message from failed deletion attempt
    @Published var deleteAccountError: String?

    // MARK: - Dependencies

    private let userService: UserService
    private weak var userSession: UserSession?

    // MARK: - Initialization

    /// Initializes the account view model with required dependencies.
    init(userService: UserService, userSession: UserSession) {
        self.userService = userService
        self.userSession = userSession
    }

    // MARK: - Public Methods

    /// Shows the initial delete account warning (Step 1 of 2).
    func showDeleteWarning() {
        showDeleteAccountWarning = true
    }

    /// Proceeds from warning to final confirmation (Step 2 of 2).
    func proceedToFinalConfirmation() {
        showDeleteAccountWarning = false
        showDeleteAccountConfirmation = true
    }

    /// Cancels the delete account flow and resets state.
    func cancelDeleteAccount() {
        showDeleteAccountWarning = false
        showDeleteAccountConfirmation = false
        deleteAccountError = nil
    }

    /// Initiates account deletion with UI state management.
    func initiateAccountDeletion() {
        isDeletingAccount = true
        deleteAccountError = nil

        deleteAccount { [weak self] success, errorMessage in
            guard let self = self else { return }

            self.isDeletingAccount = false

            if success {
                self.showDeleteAccountConfirmation = false
            } else {
                self.deleteAccountError = errorMessage ?? "Failed to delete account. Please try again."
            }
        }
    }

    /// Clears the delete account error state.
    func clearDeleteAccountError() {
        deleteAccountError = nil
    }

    /// Resets all account deletion state (used during logout).
    func resetAllData() {
        showDeleteAccountWarning = false
        showDeleteAccountConfirmation = false
        isDeletingAccount = false
        deleteAccountError = nil
    }

    // MARK: - Private Methods

    /// Deletes user account and all associated data.
    private func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let userId = userSession?.currentUserId else {
            completion(false, "No user ID found")
            return
        }

        // Capture userService before entering closure to avoid MainActor isolation issues
        let service = userService

        // Delete user data from database
        service.deleteUserAccount(userId: userId) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileAccountViewModel] Error deleting account: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                } else {
                    // Delete Supabase Auth user
                    Task { @MainActor in
                        do {
                            try await SupabaseAuthService.shared.deleteAccount()

                            // Log out the user
                            self?.userSession?.logout()

                            completion(true, nil)
                        } catch {
                            print("❌ [ProfileAccountViewModel] Error deleting Supabase Auth user: \(error.localizedDescription)")
                            completion(false, "Failed to delete authentication account: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
