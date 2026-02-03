//
//  ListStoryShareButton.swift
//  loc
//
//  Created by Claude on 1/30/25.
//

import SwiftUI

/// Button component that triggers the story card share flow with photo selection.
struct ListStoryShareButton: View {
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    let userId: String

    @StateObject private var viewModel = ListStoryCardViewModel()
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var showPhotoSelector = false

    var body: some View {
        Button {
            prepareAndShowSelector()
        } label: {
            Group {
                if viewModel.isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isGenerating)
        .sheet(isPresented: $showPhotoSelector) {
            StoryPhotoSelectorView(
                viewModel: viewModel,
                onShareInstagram: shareToInstagram,
                onShareGeneral: shareGeneral
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Link Copied!", isPresented: $viewModel.showLinkCopiedInstruction) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Tap the sticker icon in Instagram, select \"Link\", and paste to add a clickable link to your story.")
        }
    }

    /// Prepares photo options and shows the selector sheet.
    private func prepareAndShowSelector() {
        Task {
            await viewModel.preparePhotoOptions(places: places)
            showPhotoSelector = true
        }
    }

    /// Shares to Instagram Stories with link back to the app.
    private func shareToInstagram() {
        Task {
            await viewModel.shareToInstagram(
                list: list,
                places: places,
                userId: userId
            )
        }
    }

    /// Shares via system share sheet with QR code.
    private func shareGeneral() {
        Task {
            await viewModel.shareGeneral(
                list: list,
                places: places,
                userId: userId,
                shareService: serviceContainer.placeShareService
            )
        }
    }
}
