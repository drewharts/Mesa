//
//  ContactsService.swift
//  loc
//
//  Single Responsibility: Handles device contacts access, normalization, and
//  bulk matching against the Supabase users table.
//
//  Privacy: Contact phone numbers are only read and uploaded after the user has
//  given explicit in-app consent (App Store Guideline 5.1.2). The consent gate is
//  enforced here so no caller can upload contacts without it.
//

import Contacts
import Foundation
import Supabase

/// The user's in-app decision about uploading contact phone numbers for friend matching.
enum ContactsUploadConsent: String {
    case notAsked
    case granted
    case declined
}

/// The result of attempting to match device contacts against Mesa users.
enum ContactsMatchOutcome {
    case consentRequired
    case consentDeclined
    case accessDenied
    case matched([ProfileData])
}

@MainActor
class ContactsService {

    private static let consentKey = "contactsUploadConsent"

    private nonisolated(unsafe) let contactStore = CNContactStore()
    private let defaults: UserDefaults

    /// Creates the service backed by the given defaults store for consent persistence.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Consent

    /// Returns the user's persisted decision about uploading contacts.
    var uploadConsent: ContactsUploadConsent {
        defaults.string(forKey: Self.consentKey)
            .flatMap(ContactsUploadConsent.init(rawValue:)) ?? .notAsked
    }

    /// Persists the user's decision about uploading contacts for friend matching.
    func recordUploadConsent(granted: Bool) {
        let consent: ContactsUploadConsent = granted ? .granted : .declined
        defaults.set(consent.rawValue, forKey: Self.consentKey)
    }

    // MARK: - Matching

    /// Matches device contacts against Mesa users, only after in-app consent and system permission are granted.
    func findMatchingUsers(requestingUserId: String) async -> ContactsMatchOutcome {
        switch uploadConsent {
        case .notAsked: return .consentRequired
        case .declined: return .consentDeclined
        case .granted: break
        }

        guard await requestAccess() else { return .accessDenied }

        let phoneNumbers = await fetchNormalizedPhoneNumbers()
        guard !phoneNumbers.isEmpty else { return .matched([]) }

        do {
            let matches = try await matchContacts(phoneNumbers: phoneNumbers, requestingUserId: requestingUserId)
            return .matched(matches)
        } catch {
            print("❌ [ContactsService] Contact matching failed: \(error.localizedDescription)")
            return .matched([])
        }
    }

    // MARK: - Contacts Access

    /// Requests contacts permission from the user, returning true if granted.
    private func requestAccess() async -> Bool {
        do {
            return try await contactStore.requestAccess(for: .contacts)
        } catch {
            print("❌ [ContactsService] Contacts access error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Fetch & Normalize

    /// Fetches all phone numbers from the user's contacts and normalizes them to E.164 format.
    private func fetchNormalizedPhoneNumbers() async -> [String] {
        let keysToFetch: [CNKeyDescriptor] = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        var normalizedNumbers = Set<String>()

        do {
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            try await Task.detached {
                try self.contactStore.enumerateContacts(with: request) { contact, _ in
                    for phoneNumber in contact.phoneNumbers {
                        let raw = phoneNumber.value.stringValue
                        if let normalized = PhoneNumberNormalizer.normalize(raw, dialCode: "+1") {
                            normalizedNumbers.insert(normalized)
                        }
                    }
                }
            }.value
        } catch {
            print("❌ [ContactsService] Error fetching contacts: \(error.localizedDescription)")
        }

        return Array(normalizedNumbers)
    }

    // MARK: - Match Contacts via RPC

    /// Calls the Supabase RPC to find users whose phone numbers match the provided list.
    private func matchContacts(phoneNumbers: [String], requestingUserId: String) async throws -> [ProfileData] {
        let params: [String: AnyJSON] = [
            "p_phone_numbers": .array(phoneNumbers.map { .string($0) }),
            "p_requesting_user_id": .string(requestingUserId)
        ]

        let response: [ProfileData] = try await SupabaseManager.shared.client
            .rpc("match_contacts_by_phone", params: params)
            .execute()
            .value

        return response
    }
}
