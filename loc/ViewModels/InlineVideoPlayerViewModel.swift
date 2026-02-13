//
//  InlineVideoPlayerViewModel.swift
//  loc
//
//  Manages AVPlayer state for inline muted video playback in the feed
//

import Foundation
import AVFoundation
import Combine

@MainActor
class InlineVideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying: Bool = false
    @Published var isMuted: Bool = true
    @Published var isBuffering: Bool = true

    // MARK: - Public Properties
    let player: AVPlayer

    // MARK: - Private Properties
    private nonisolated(unsafe) var loopObserver: Any?
    private let videoURL: URL
    private var statusObserver: AnyCancellable?
    private var shouldPlayWhenReady = false

    // MARK: - Init

    /// Initializes the player with a remote video URL and observes buffering state.
    init(url: URL) {
        self.videoURL = url
        self.player = AVPlayer(url: url)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = true
        setupLooping()
        setupStatusObserver()
    }

    deinit {
        removeLoopObserver()
    }

    // MARK: - Playback Controls

    /// Starts playback if ready, otherwise queues autoplay for when buffering completes.
    func play() {
        if isBuffering {
            shouldPlayWhenReady = true
        } else {
            player.play()
            isPlaying = true
        }
    }

    /// Pauses playback.
    func pause() {
        shouldPlayWhenReady = false
        player.pause()
        isPlaying = false
    }

    /// Toggles the muted state.
    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    // MARK: - Private Helpers

    /// Observes the player item status to detect when the video is ready to play.
    private func setupStatusObserver() {
        guard let item = player.currentItem else { return }
        statusObserver = item.publisher(for: \.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                if status == .readyToPlay {
                    self.isBuffering = false
                    if self.shouldPlayWhenReady {
                        self.player.play()
                        self.isPlaying = true
                    }
                }
            }
    }

    /// Observes playback end to loop the video from the start.
    private func setupLooping() {
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
    }

    /// Removes the loop observer to prevent leaks.
    private nonisolated func removeLoopObserver() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
