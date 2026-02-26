//
//  PhoneOnboardingViewModel.swift
//  loc
//
//  Single Responsibility: Manages state and logic for the phone number onboarding step.
//  Handles input validation, normalization, and submission to Supabase.
//

import Foundation

@MainActor
class PhoneOnboardingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var phoneInput: String = ""
    @Published var selectedCountryCode: CountryCode = .defaultCountry
    @Published var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published var isOnboardingComplete: Bool = false

    // MARK: - Dependencies

    private let userId: String

    // MARK: - Computed Properties

    /// Returns the phone number normalized to E.164 format, or nil if invalid.
    var normalizedNumber: String? {
        PhoneNumberNormalizer.normalize(phoneInput, dialCode: selectedCountryCode.dialCode)
    }

    /// Validates that the phone input has enough digits to be a real number.
    var isValidNumber: Bool {
        let digits = phoneInput.filter(\.isWholeNumber)
        return digits.count >= 7
    }

    // MARK: - Initialization

    init(userId: String) {
        self.userId = userId
    }

    // MARK: - Actions

    /// Validates, normalizes, and saves the phone number to the user's profile.
    func submitPhoneNumber() async {
        guard let normalized = normalizedNumber else {
            errorMessage = "Please enter a valid phone number."
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(["phone_number": normalized])
                .eq("id", value: userId)
                .execute()

            isOnboardingComplete = true
        } catch {
            errorMessage = "Failed to save phone number. Please try again."
            print("❌ [PhoneOnboardingVM] Error saving phone number: \(error.localizedDescription)")
        }

        isSubmitting = false
    }

}
