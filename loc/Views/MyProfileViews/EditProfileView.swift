//
//  EditProfileView.swift
//  loc
//
//  Sheet for editing profile name, photo, and social media links.
//

import SwiftUI

struct EditProfileView: View {
    @StateObject var viewModel: EditProfileViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    var onSave: ((ProfileData) -> Void)?

    private let originalUser: ProfileData

    @State private var showingImagePicker = false
    @State private var editRequest: ProfilePhotoEditRequest?
    @State private var showingOptions = false
    @State private var didSave = false

    init(user: ProfileData, onSave: ((ProfileData) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: EditProfileViewModel(user: user))
        self.originalUser = user
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                errorSection
                profilePhotoSection
                nameSection
                socialLinksSection
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    saveButton
                }
            }
            .confirmationDialog("Profile Photo", isPresented: $showingOptions, titleVisibility: .hidden) {
                Button("Adjust Crop") { editRequest = profile.profilePhotoAdjustRequest() }
                Button("Choose New Photo") { showingImagePicker = true }
                Button("Cancel", role: .cancel) {}
            }
            .profilePhotoEditor(showPicker: $showingImagePicker,
                                editRequest: $editRequest,
                                source: "edit_profile",
                                userId: profile.user?.id) { cropped, original in
                Task { await profile.changeProfilePhoto(cropped: cropped, original: original) }
            }
        }
    }

    // MARK: - Sections

    /// Displays the current profile photo with a button to change it
    private var profilePhotoSection: some View {
        Section {
            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    profileImage
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .shadow(radius: 2)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
                .onTapGesture {
                    if !profile.isUploadingProfilePhoto {
                        if profile.userPicture != nil {
                            showingOptions = true
                        } else {
                            showingImagePicker = true
                        }
                    }
                }
                .overlay {
                    if profile.isUploadingProfilePhoto {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 80, height: 80)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    /// Resolves the current profile image from ProfileViewModel
    private var profileImage: some View {
        Group {
            if let photo = profile.userPicture {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.blue)
            }
        }
    }

    private var nameSection: some View {
        Section(header: Text("Name")) {
            TextField("First Name", text: $viewModel.firstName)
                .textContentType(.givenName)
                .autocorrectionDisabled()
            TextField("Last Name", text: $viewModel.lastName)
                .textContentType(.familyName)
                .autocorrectionDisabled()
        }
    }

    private var socialLinksSection: some View {
        Section(header: Text("Social Links")) {
            HStack {
                Text("@")
                    .foregroundColor(.secondary)
                TextField("Instagram username", text: $viewModel.instagramUsername)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            HStack {
                Text("@")
                    .foregroundColor(.secondary)
                TextField("TikTok username", text: $viewModel.tiktokUsername)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.saveError {
            Section {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    /// Save → spinner → green "✓ Saved" with a success haptic, then the sheet closes after ~0.8s.
    private var saveButton: some View {
        SaveStatusButton(isSaving: viewModel.isSaving,
                         didSave: didSave,
                         isEnabled: viewModel.hasChanges) {
            Task {
                let success = await viewModel.saveProfile()
                if success {
                    let updated = viewModel.updatedProfileData(from: originalUser)
                    onSave?(updated)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { didSave = true }
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    dismiss()
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

/// Toolbar save button with clear states: "Save", a spinner while saving, then a green checkmark + "Saved".
struct SaveStatusButton: View {
    let isSaving: Bool
    let didSave: Bool
    var isEnabled: Bool = true
    var title: String = "Save"
    let action: () -> Void

    var body: some View {
        Group {
            if didSave {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Saved")
            } else if isSaving {
                ProgressView()
            } else {
                Button(title, action: action)
                    .fontWeight(.semibold)
                    .disabled(!isEnabled)
            }
        }
    }
}
