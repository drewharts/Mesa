//
//  FullscreenVideoPlayerViewModel.swift
//  loc
//
//  Manages AVPlayer state for fullscreen video playback with sound
//

import Foundation
import AVFoundation
import Combine

@MainActor
class FullscreenVideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying: Bool = true
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    // MARK: - Public Properties
    let player: AVPlayer

    // MARK: - Private Properties
    private var timeObserver: Any?

    // MARK: - Init

    /// Initializes the fullscreen player with a remote video URL, unmuted.
    init(url: URL, autoPlay: Bool = true) {
        self.player = AVPlayer(url: url)
        player.isMuted = false
        activateAudioSession()
        setupTimeObserver()
        loadDuration()
        if autoPlay {
            player.play()
        } else {
            isPlaying = false
        }
    }

    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }

    // MARK: - Playback Controls

    /// Toggles between play and pause.
    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    /// Seeks to a specific time in seconds.
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
    }

    // MARK: - Private Helpers

    /// Activates the audio session for playback.
    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[FullscreenVideoPlayerVM] Audio session error: \(error)")
        }
    }

    /// Adds a periodic time observer to track playback position.
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = CMTimeGetSeconds(time)
            }
        }
    }

    /// Loads the total duration of the video asset.
    private func loadDuration() {
        Task {
            guard let item = player.currentItem else { return }
            let assetDuration = try? await item.asset.load(.duration)
            if let assetDuration {
                duration = CMTimeGetSeconds(assetDuration)
            }
        }
    }
}
