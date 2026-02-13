//
//  FullscreenVideoPlayerView.swift
//  loc
//
//  Fullscreen video player with controls, unmuted by default
//

import SwiftUI
import AVFoundation

struct FullscreenVideoPlayerView: View {
    @StateObject private var viewModel: FullscreenVideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(url: URL) {
        _viewModel = StateObject(wrappedValue: FullscreenVideoPlayerViewModel(url: url))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            AVPlayerFillView(player: viewModel.player)
                .ignoresSafeArea()
                .onTapGesture { viewModel.togglePlayPause() }

            controlsOverlay
        }
        .gesture(dismissDragGesture)
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            dismissButton
            Spacer()
            if !viewModel.isPlaying {
                pauseIndicator
            }
            Spacer()
            scrubberBar
        }
    }

    /// Close button in the top-right corner.
    private var dismissButton: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
    }

    /// Large play icon shown when paused.
    private var pauseIndicator: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 48))
            .foregroundColor(.secondary.opacity(0.7))
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
            .tint(.primary)

            HStack {
                Text(formatTime(viewModel.currentTime))
                Spacer()
                Text(formatTime(viewModel.duration))
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    /// Formats seconds into m:ss display string.
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    /// Swipe-down gesture to dismiss the fullscreen player.
    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                if value.translation.height > 100 {
                    dismiss()
                }
            }
    }
}
