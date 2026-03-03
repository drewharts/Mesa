//
//  ProfileBannerView.swift
//  loc
//
//  Reusable dumb component that displays a profile banner photo.
//

import SwiftUI

struct ProfileBannerView: View {
    let bannerPhotoURL: URL?
    let localBannerImage: UIImage?
    let isUploading: Bool
    let isEditable: Bool
    let onTapChange: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            bannerContent
                .frame(maxWidth: .infinity)
                .aspectRatio(3, contentMode: .fill)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditable, !isUploading {
                        onTapChange?()
                    }
                }

            // Camera icon overlay for editable banners
            if isEditable, !isUploading {
                cameraOverlay
            }

            // Upload progress overlay
            if isUploading {
                uploadOverlay
            }
        }
    }

    // MARK: - Banner Content

    @ViewBuilder
    private var bannerContent: some View {
        if let localImage = localBannerImage {
            Image(uiImage: localImage)
                .resizable()
                .scaledToFill()
        } else if let url = bannerPhotoURL {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholderGradient
            }
        } else {
            placeholderGradient
        }
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [Color(.systemGray5), Color(.systemGray4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cameraOverlay: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(6)
            .background(Circle().fill(Color.black.opacity(0.5)))
            .padding(8)
    }

    private var uploadOverlay: some View {
        Color.black.opacity(0.4)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            )
    }
}
