//
//  ProfilePhotoOnboardingView.swift
//  loc
//
//  Single Responsibility: Purely declarative UI for the required profile photo onboarding step.
//  Displays image preview, photo picker, and upload button. Non-dismissible.
//

import SwiftUI

struct ProfilePhotoOnboardingView: View {
    @StateObject private var viewModel = ProfilePhotoOnboardingViewModel()
    @EnvironmentObject var userSession: UserSession

    @State private var pickerImages: [UIImage] = []
    @State private var showImagePicker = false

    var body: some View {
        VStack(spacing: 24) {
            headerSection

            photoPreviewSection

            choosePhotoButton

            continueButton

            Spacer()
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(images: $pickerImages, selectionLimit: 1)
        }
        .onChange(of: pickerImages) { _, newImages in
            if let image = newImages.last {
                viewModel.handleImageSelected(image)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Add a Profile Photo")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose a photo so your friends can recognize you")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var photoPreviewSection: some View {
        Group {
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray.opacity(0.4))
                    )
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
            }
        }
    }

    private var choosePhotoButton: some View {
        Button {
            showImagePicker = true
        } label: {
            Text(viewModel.selectedImage == nil ? "Choose Photo" : "Change Photo")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
        .disabled(viewModel.isUploading)
    }

    private var continueButton: some View {
        VStack(spacing: 8) {
            Button {
                guard let userId = userSession.currentUserId else { return }
                Task {
                    let success = await viewModel.uploadPhoto(userId: userId)
                    if success {
                        PresentationService.shared.dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if SuggestedProfilesViewModel.shouldShowPopup {
                                PresentationService.shared.present(.suggestedProfiles)
                            }
                        }
                    }
                }
            } label: {
                Group {
                    if viewModel.isUploading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(viewModel.selectedImage != nil ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.selectedImage == nil || viewModel.isUploading)

            if let error = viewModel.uploadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
