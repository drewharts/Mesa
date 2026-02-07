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
    @State private var inputImage: [UIImage] = []

    init(user: ProfileData, onSave: ((ProfileData) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: EditProfileViewModel(user: user))
        self.originalUser = user
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                profilePhotoSection
                nameSection
                socialLinksSection
                errorSection
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
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(images: $inputImage, selectionLimit: 1)
            }
            .onChange(of: inputImage) { _, newValue in
                guard let newImage = newValue.first else { return }
                Task {
                    await profile.changeProfilePhoto(newImage)
                    inputImage.removeAll()
                }
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
                        showingImagePicker = true
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

    private var saveButton: some View {
        Group {
            if viewModel.isSaving {
                ProgressView()
            } else {
                Button("Save") {
                    Task {
                        let success = await viewModel.saveProfile()
                        if success {
                            let updated = viewModel.updatedProfileData(from: originalUser)
                            onSave?(updated)
                            dismiss()
                        }
                    }
                }
                .disabled(!viewModel.hasChanges)
            }
        }
    }
}
