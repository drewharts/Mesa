//
//  EditProfileViewModel.swift
//  loc
//
//  ViewModel for the Edit Profile sheet. Handles name and social link editing.
//

import Foundation

@MainActor
class EditProfileViewModel: ObservableObject {
    @Published var firstName: String
    @Published var lastName: String
    @Published var instagramUsername: String
    @Published var tiktokUsername: String
    @Published var isSaving: Bool = false
    @Published var saveError: String?

    private let originalFirstName: String
    private let originalLastName: String
    private let originalInstagram: String
    private let originalTikTok: String
    private let userId: String

    /// Initializes the view model with the current user's profile data
    init(user: ProfileData) {
        self.userId = user.id
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.instagramUsername = user.instagramUsername ?? ""
        self.tiktokUsername = user.tiktokUsername ?? ""

        self.originalFirstName = user.firstName
        self.originalLastName = user.lastName
        self.originalInstagram = user.instagramUsername ?? ""
        self.originalTikTok = user.tiktokUsername ?? ""
    }

    /// Whether any field has been changed from its original value
    var hasChanges: Bool {
        firstName != originalFirstName ||
        lastName != originalLastName ||
        sanitizedHandle(instagramUsername) != sanitizedHandle(originalInstagram) ||
        sanitizedHandle(tiktokUsername) != sanitizedHandle(originalTikTok)
    }

    /// Saves the profile changes to the database and returns true on success
    func saveProfile() async -> Bool {
        isSaving = true
        saveError = nil

        var updates: [String: String] = [:]

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedFirst != originalFirstName {
            updates["first_name"] = trimmedFirst
        }
        if trimmedLast != originalLastName {
            updates["last_name"] = trimmedLast
        }

        // Recalculate full_name and full_name_lower if name changed
        if updates.keys.contains("first_name") || updates.keys.contains("last_name") {
            let newFullName = "\(trimmedFirst) \(trimmedLast)"
            updates["full_name"] = newFullName
            updates["full_name_lower"] = newFullName.lowercased()
        }

        let cleanInstagram = sanitizedHandle(instagramUsername)
        let cleanTikTok = sanitizedHandle(tiktokUsername)

        if cleanInstagram != sanitizedHandle(originalInstagram) {
            updates["instagram_username"] = cleanInstagram
        }
        if cleanTikTok != sanitizedHandle(originalTikTok) {
            updates["tiktok_username"] = cleanTikTok
        }

        guard !updates.isEmpty else {
            isSaving = false
            return true
        }

        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(updates)
                .eq("id", value: userId)
                .execute()

            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Builds an updated ProfileData reflecting the current field values
    func updatedProfileData(from original: ProfileData) -> ProfileData {
        var updated = original
        updated.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.fullName = "\(updated.firstName) \(updated.lastName)"
        updated.fullNameLower = updated.fullName.lowercased()
        let ig = sanitizedHandle(instagramUsername)
        updated.instagramUsername = ig.isEmpty ? nil : ig
        let tt = sanitizedHandle(tiktokUsername)
        updated.tiktokUsername = tt.isEmpty ? nil : tt
        return updated
    }

    /// Strips leading @ and trims whitespace from a social handle
    private func sanitizedHandle(_ handle: String) -> String {
        var cleaned = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("@") {
            cleaned = String(cleaned.dropFirst())
        }
        return cleaned
    }
}
