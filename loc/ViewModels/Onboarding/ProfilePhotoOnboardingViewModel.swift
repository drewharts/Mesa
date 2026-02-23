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
    @Published var existingPhotoURL: URL?
    @Published var existingPhoto: UIImage?
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?
    @Published var showImagePicker: Bool = false
    @Published var pickerImages: [UIImage] = []
    @Published var isOnboardingComplete = false

    private let userId: String
    private var cancellables = Set<AnyCancellable>()

    /// Initializes the view model with the current user's ID and sets up the image picker binding.
    init(userId: String) {
        self.userId = userId
        setupPickerBinding()
    }

    /// Syncs the first image from the picker binding to selectedImage.
    private func setupPickerBinding() {
        $pickerImages
            .dropFirst()
            .compactMap { $0.first }
            .sink { [weak self] image in
                self?.selectedImage = image
            }
            .store(in: &cancellables)
    }

    /// The image to display in the preview circle.
    var displayImage: UIImage? {
        selectedImage ?? existingPhoto
    }

    /// Whether the user can proceed (has some photo to use).
    var canContinue: Bool {
        displayImage != nil
    }

    /// Whether the user picked a new photo (vs keeping existing Google photo).
    var hasNewPhoto: Bool {
        selectedImage != nil
    }

    /// Fetches any existing Google profile photo from the user's profile for preview display.
    func loadExistingGooglePhoto() {
        Task {
            do {
                let profile = try await UserService.shared.fetchUserById(userId: userId)
                if let url = profile.profilePhotoURL {
                    loadExistingPhoto(url: url)
                }
            } catch {
                // Non-fatal: user may not have an existing photo yet
            }
        }
    }

    /// Handles the continue button tap: uploads if new photo, or completes immediately for existing.
    func handleContinue() {
        if hasNewPhoto {
            Task {
                let success = await uploadProfilePhoto()
                if success {
                    isOnboardingComplete = true
                }
            }
        } else {
            isOnboardingComplete = true
        }
    }

    /// Downloads a photo from the given URL and sets it as the existing profile photo preview.
    private func loadExistingPhoto(url: URL) {
        self.existingPhotoURL = url

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    self.existingPhoto = image
                }
            } catch {
                // Non-fatal: preview will show placeholder
            }
        }
    }

    /// Uploads the selected profile photo and updates the database.
    private func uploadProfilePhoto() async -> Bool {
        guard let imageToUpload = selectedImage else { return false }

        isUploading = true
        errorMessage = nil

        do {
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
