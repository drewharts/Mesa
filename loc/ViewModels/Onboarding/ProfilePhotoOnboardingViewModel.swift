//
//  ProfilePhotoOnboardingViewModel.swift
//  loc
//
//  Created for profile photo onboarding step during sign-up.
//

import SwiftUI
import Combine

@MainActor
class ProfilePhotoOnboardingViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?
    @Published var showImagePicker: Bool = false
    @Published var editRequest: ProfilePhotoEditRequest?
    /// Uncropped photo the user picked, kept so the crop can be re-adjusted.
    private(set) var originalImage: UIImage?
    @Published var isOnboardingComplete = false

    private let userId: String
    private var cancellables = Set<AnyCancellable>()

    /// Initializes the view model with the current user's ID and sets up the image picker binding.
    init(userId: String) {
        self.userId = userId
    }

    var userIdForCrop: String { userId }

    /// Called by the shared crop editor when the user taps Done.
    func applyCrop(cropped: UIImage, original: UIImage) {
        selectedImage = cropped
        originalImage = original
    }

    /// Re-open the crop editor on the original photo.
    func adjustCrop() {
        guard let original = originalImage else { return }
        editRequest = ProfilePhotoEditRequest(image: original, isNewPhoto: false, restoreSavedState: true)
    }

    /// Whether the user can proceed (has selected a photo).
    var canContinue: Bool {
        selectedImage != nil
    }

    /// Handles the continue button tap: uploads the selected photo.
    func handleContinue() {
        Task {
            let success = await uploadProfilePhoto()
            if success {
                isOnboardingComplete = true
            }
        }
    }

    /// Uploads the selected profile photo and updates the database.
    private func uploadProfilePhoto() async -> Bool {
        guard let imageToUpload = selectedImage else { return false }

        isUploading = true
        errorMessage = nil

        do {
            if let originalImage {
                ProfilePhotoOriginalStore.save(originalImage, userId: userId)
            }
            let croppedImage = cropToSquare(imageToUpload)
            let photoURL = try await ImageService.shared.updateProfilePhoto(userId: userId, image: croppedImage)
            try await updateProfilePhotoInDatabase(photoURL: photoURL)

            isUploading = false
            return true
        } catch {
            isUploading = false
            errorMessage = "Failed to upload photo. Please try again."
            return false
        }
    }

    /// Updates the profile_photo_url column in the users table.
    private func updateProfilePhotoInDatabase(photoURL: URL) async throws {
        try await SupabaseManager.shared.client
            .from("users")
            .update(["profile_photo_url": photoURL.absoluteString])
            .eq("id", value: userId)
            .execute()
    }

    /// Crops an image to a centered square.
    private func cropToSquare(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let contextSize = CGSize(width: cgImage.width, height: cgImage.height)

        let size = min(contextSize.width, contextSize.height)
        let x = (contextSize.width - size) / 2
        let y = (contextSize.height - size) / 2
        let cropRect = CGRect(x: x, y: y, width: size, height: size)

        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        }

        return image
    }
}
