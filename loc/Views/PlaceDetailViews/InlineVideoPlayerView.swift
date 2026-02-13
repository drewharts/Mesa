//
//  InlineVideoPlayerView.swift
//  loc
//
//  Inline muted autoplay video player for the post feed
//

import SwiftUI
import AVFoundation

struct InlineVideoPlayerView: View {
    @StateObject private var viewModel: InlineVideoPlayerViewModel
    let thumbnailURL: URL?
    let onTap: () -> Void

    // MARK: - Init

    init(url: URL, thumbnailURL: URL? = nil, onTap: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: InlineVideoPlayerViewModel(url: url))
        self.thumbnailURL = thumbnailURL
        self.onTap = onTap
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            videoLayer
                .opacity(viewModel.isBuffering ? 0 : 1)

            if viewModel.isBuffering {
                bufferingPlaceholder
            }

            muteButton

            if !viewModel.isPlaying && !viewModel.isBuffering {
                playOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { viewModel.play() }
        .onDisappear { viewModel.pause() }
        .onTapGesture { onTap() }
    }

    // MARK: - Subviews

    /// The AVPlayer video layer with aspect-fill cropping.
    private var videoLayer: some View {
        AVPlayerFillView(player: viewModel.player)
    }

    /// Thumbnail or placeholder shown while the video buffers.
    private var bufferingPlaceholder: some View {
        ZStack {
            if let thumbnailURL {
                AsyncImage(url: thumbnailURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                }
            } else {
                Color(.systemGray5)
            }

            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
        }
    }

    /// Mute/unmute button in the bottom-leading corner.
    private var muteButton: some View {
        Button(action: { viewModel.toggleMute() }) {
            Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.caption)
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .padding(8)
    }

    /// Semi-transparent play icon overlay when paused.
    private var playOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            Image(systemName: "play.fill")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.8))
        }
        .allowsHitTesting(false)
    }
}
