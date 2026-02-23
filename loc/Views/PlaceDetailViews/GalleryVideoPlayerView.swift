//
//  GalleryVideoPlayerView.swift
//  loc
//
//  Embeddable video player page for use inside FullscreenMediaGalleryView TabView.
//

import SwiftUI
import AVFoundation

struct GalleryVideoPlayerView: View {
    let url: URL
    let isActive: Bool

    @StateObject private var viewModel: FullscreenVideoPlayerViewModel

    init(url: URL, isActive: Bool) {
        self.url = url
        self.isActive = isActive
        _viewModel = StateObject(wrappedValue: FullscreenVideoPlayerViewModel(url: url, autoPlay: false))
    }

    var body: some View {
        ZStack {
            AVPlayerFillView(player: viewModel.player)
                .ignoresSafeArea()
                .onTapGesture { viewModel.togglePlayPause() }

            if !viewModel.isPlaying {
                pauseIndicator
            }

            VStack {
                Spacer()
                scrubberBar
            }
        }
        .onAppear {
            handleActiveChange(isActive)
        }
        .onChange(of: isActive) { _, active in
            handleActiveChange(active)
        }
    }

    // MARK: - Subviews

    /// Large play icon shown when video is paused.
    private var pauseIndicator: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 48))
            .foregroundColor(.white.opacity(0.7))
            .allowsHitTesting(false)
    }

    /// Time scrubber bar with current and total time labels.
    private var scrubberBar: some View {
        VStack(spacing: 4) {
            Slider(
                value: $viewModel.currentTime,
                in: 0...max(viewModel.duration, 1),
                onEditingChanged: { editing in
                    if !editing {
                        viewModel.seek(to: viewModel.currentTime)
                    }
                }
            )
            .tint(.white)

            HStack {
                Text(formatTime(viewModel.currentTime))
                Spacer()
                Text(formatTime(viewModel.duration))
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    /// Pauses or resumes playback based on whether this page is the active tab.
    private func handleActiveChange(_ active: Bool) {
        if active {
            viewModel.player.play()
            viewModel.isPlaying = true
        } else {
            viewModel.player.pause()
            viewModel.isPlaying = false
        }
    }

    /// Formats seconds into m:ss display string.
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}
