//
//  ListShareMenuButton.swift
//  loc
//
//  Created by Claude on 2/1/26.
//

import SwiftUI

/// Unified share button for lists that combines link sharing and story card creation.
struct ListShareMenuButton: View {
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    let userId: String

    @StateObject private var storyViewModel = ListStoryCardViewModel()
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var showPhotoSelector = false

    var body: some View {
        Menu {
            Button {
                shareLink()
            } label: {
                Label("Share Link", systemImage: "link")
            }

            Button {
                prepareAndShowPhotoSelector()
            } label: {
                Label("Create Story Card", systemImage: "camera.fill")
            }
        } label: {
            Group {
                if storyViewModel.isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .disabled(storyViewModel.isGenerating)
        .sheet(isPresented: $showPhotoSelector) {
            StoryPhotoSelectorView(
                viewModel: storyViewModel,
                onShareInstagram: shareToInstagram,
                onShareGeneral: shareGeneral
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Link Copied!", isPresented: $storyViewModel.showLinkCopiedInstruction) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Tap the sticker icon in Instagram, select \"Link\", and paste to add a clickable link to your story.")
        }
    }

    /// Shares the list link via system share sheet.
    private func shareLink() {
        serviceContainer.placeShareService.shareLightweightList(list, userId: userId)
    }

    /// Prepares photo options and shows the selector sheet.
    private func prepareAndShowPhotoSelector() {
        Task {
            await storyViewModel.preparePhotoOptions(places: places)
            showPhotoSelector = true
        }
    }

    /// Shares to Instagram Stories with link back to the app.
    private func shareToInstagram() {
        Task {
            await storyViewModel.shareToInstagram(
                list: list,
                places: places,
                userId: userId
            )
        }
    }

    /// Shares via system share sheet with QR code.
    private func shareGeneral() {
        Task {
            await storyViewModel.shareGeneral(
                list: list,
                places: places,
                userId: userId,
                shareService: serviceContainer.placeShareService
            )
        }
    }
}
