//
//  ProfilePhotoOnboardingViewModel.swift
//  loc
//
//  Single Responsibility: Manages state and logic for the required profile photo onboarding step.
//  Handles image selection, square cropping, upload to Supabase Storage, and DB update.
//

import Foundation
import UIKit

@MainActor
class ProfilePhotoOnboardingViewModel: ObservableObject {

    // MARK: - UserDefaults Key

    private static let hasCompletedKey = "hasCompletedProfilePhotoOnboarding"

    // MARK: - Published State

    @Published var selectedImage: UIImage?
    @Published var isUploading = false
    @Published var uploadError: String?

    // MARK: - Dependencies

    private let imageService = ImageService.shared

    // MARK: - Static Methods

    /// Returns whether the profile photo onboarding should be shown (first login only).
    static var shouldShowOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: hasCompletedKey)
    }

    /// Resets the onboarding completion status for testing purposes.
    static func resetOnboardingStatus() {
        UserDefaults.standard.removeObject(forKey: hasCompletedKey)
    }

    // MARK: - Public Methods

    /// Processes a selected image by cropping it to a square for profile use.
    func handleImageSelected(_ image: UIImage) {
        selectedImage = cropToSquare(image)
        uploadError = nil
    }

    /// Uploads the selected photo to Supabase Storage and updates the user's profile_photo_url.
    func uploadPhoto(userId: String) async -> Bool {
        guard let image = selectedImage else { return false }

        isUploading = true
        uploadError = nil

        do {
            let photoURL = try await imageService.updateProfilePhoto(userId: userId, image: image)
            try await updateProfilePhotoInDatabase(userId: userId, photoURL: photoURL)
            markOnboardingComplete()
            isUploading = false
            return true
        } catch {
            uploadError = error.localizedDescription
            isUploading = false
            return false
        }
    }

    // MARK: - Private Methods

    /// Marks the profile photo onboarding as complete so it won't show again.
    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedKey)
    }

    /// Updates the users table with the new profile photo URL.
    private func updateProfilePhotoInDatabase(userId: String, photoURL: URL) async throws {
        let supabase = SupabaseManager.shared

        try await supabase.client
            .from("users")
            .update(["profile_photo_url": photoURL.absoluteString])
            .eq("id", value: userId)
            .execute()
    }

    /// Crops an image to a square by centering and trimming the longer dimension.
    private func cropToSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let contextImage = UIImage(cgImage: cgImage)
        let contextSize = contextImage.size

        let size = min(contextSize.width, contextSize.height)

        let x = (contextSize.width - size) / 2
        let y = (contextSize.height - size) / 2
        let cropRect = CGRect(
            x: x * image.scale,
            y: y * image.scale,
            width: size * image.scale,
            height: size * image.scale
        )

        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        }

        return image
    }
}
