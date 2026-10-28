//
//  AnimatedSplashView.swift
//  loc
//
//  In-app animated splash. The real iOS launch screen must stay static, so Info.plist's
//  UILaunchScreen shows only the SplashBackground color; this view starts from that exact
//  color, assembles the MESA wordmark letter by letter, and lands on a frame pixel-aligned
//  with the static SplashScreen asset (same scaledToFill geometry) before handing off.
//

import SwiftUI

struct AnimatedSplashView: View {
    /// Called once the intro has finished (or was skipped).
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = [false, false, false, false]
    @State private var underline = false
    @State private var didFinish = false

    /// Letter frames in SplashScreen.png pixel coordinates (1290 x 2813 canvas).
    private static let canvas = CGSize(width: 1290, height: 2813)
    private static let letters: [(name: String, rect: CGRect)] = [
        ("SplashLetterM", CGRect(x: 313, y: 1270, width: 147, height: 147)),
        ("SplashLetterE", CGRect(x: 513, y: 1270, width: 123, height: 147)),
        ("SplashLetterS", CGRect(x: 666, y: 1270, width: 139, height: 147)),
        ("SplashLetterA", CGRect(x: 825, y: 1270, width: 162, height: 147)),
    ]

    var body: some View { analyticsBody.analyticsScreen("Splash") }

    @ViewBuilder private var analyticsBody: some View {
        GeometryReader { geo in
            // Same mapping as Image("SplashScreen").scaledToFill() centered in the screen.
            let scale = max(geo.size.width / Self.canvas.width, geo.size.height / Self.canvas.height)
            let origin = CGPoint(
                x: (geo.size.width - Self.canvas.width * scale) / 2,
                y: (geo.size.height - Self.canvas.height * scale) / 2
            )
            ZStack(alignment: .topLeading) {
                Color("SplashBackground")
                ForEach(Array(Self.letters.enumerated()), id: \.offset) { index, letter in
                    let on = revealed[index]
                    Image(letter.name)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: letter.rect.width * scale, height: letter.rect.height * scale)
                        .position(
                            x: origin.x + letter.rect.midX * scale,
                            y: origin.y + letter.rect.midY * scale
                        )
                        .opacity(on ? 1 : 0)
                        .offset(y: on || reduceMotion ? 0 : 14)
                        .blur(radius: on || reduceMotion ? 0 : 6)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { finish() }          // skippable
        .accessibilityElement()
        .accessibilityLabel("Mesa")
        .accessibilityAddTraits(.isImage)
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) { revealed = [true, true, true, true] }
            try? await Task.sleep(nanoseconds: 450_000_000)
            finish()
            return
        }
        // ~1.2s total: 4 letters staggered 90ms on a soft spring, short hold on the final frame.
        for i in revealed.indices {
            guard !didFinish else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { revealed[i] = true }
            try? await Task.sleep(nanoseconds: 90_000_000)
        }
        try? await Task.sleep(nanoseconds: 750_000_000)
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        revealed = [true, true, true, true]
        onFinished()
    }
}
