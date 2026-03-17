//
//  ContactsService.swift
//  loc
//
//  Single Responsibility: Handles device contacts access, normalization, and
//  bulk matching against the Supabase users table.
//

import Contacts
import Foundation
import Supabase

@MainActor
class ContactsService {

    private nonisolated(unsafe) let contactStore = CNContactStore()

    // MARK: - Contacts Access

    /// Requests contacts permission from the user, returning true if granted.
    func requestAccess() async -> Bool {
        do {
            return try await contactStore.requestAccess(for: .contacts)
        } catch {
            print("❌ [ContactsService] Contacts access error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Fetch & Normalize

    /// Fetches all phone numbers from the user's contacts and normalizes them to E.164 format.
    func fetchNormalizedPhoneNumbers() async -> [String] {
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
    func matchContacts(phoneNumbers: [String], requestingUserId: String) async throws -> [ProfileData] {
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
