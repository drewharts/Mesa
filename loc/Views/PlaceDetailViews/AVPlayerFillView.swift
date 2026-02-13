//
//  AVPlayerFillView.swift
//  loc
//
//  UIViewRepresentable that renders an AVPlayer with aspect-fill (crop to fill)
//

import SwiftUI
import AVFoundation

struct AVPlayerFillView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }

    /// Hosts an AVPlayerLayer with resizeAspectFill gravity.
    class PlayerUIView: UIView {
        let playerLayer: AVPlayerLayer

        init(player: AVPlayer) {
            self.playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}
