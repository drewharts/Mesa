//
//  ListStoryShareButton.swift
//  loc
//
//  Button component that triggers list share card generation.
//

import SwiftUI

/// Prominent share button for lists — supports quick share and advanced photo selection.
struct ListStoryShareButton: View {
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    let userId: String
    let style: ButtonStyle

    @StateObject private var viewModel = ListStoryCardViewModel()
    @EnvironmentObject private var serviceContainer: ServiceContainer
    @State private var showPhotoSelector = false

    /// Controls whether the button shows as an icon or a full labeled button.
    enum ButtonStyle {
        case icon
        case prominent
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            buttonLabel
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

    /// Renders the appropriate button label based on style.
    @ViewBuilder
    private var buttonLabel: some View {
        switch style {
        case .icon:
            Group {
                if viewModel.isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())

        case .prominent:
            HStack(spacing: 8) {
                if viewModel.isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.mesaAccent)
            .clipShape(Capsule())
        }
    }

    /// Triggers quick share for icon style, photo selector for prominent style.
    private func handleTap() {
        Task {
            await viewModel.quickShare(
                list: list,
                places: places,
                userId: userId,
                shareService: serviceContainer.placeShareService
            )
        }
    }

    /// Shares to Instagram Stories with link back to the app.
    private func shareToInstagram() {
        Task {
            await viewModel.shareToInstagram(list: list, places: places, userId: userId)
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
