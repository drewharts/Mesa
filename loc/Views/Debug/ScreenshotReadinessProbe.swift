//
//  ScreenshotReadinessProbe.swift
//  loc
//
//  DEBUG-only invisible accessibility element ("screenshot.ready") whose value reports loading
//  state to the screenshot UI test. Not compiled into Release builds.
//

import SwiftUI

#if DEBUG
struct ScreenshotReadinessProbe: View {
    @ObservedObject private var readiness = ScreenshotReadiness.shared

    var body: some View {
        Color.clear
            .frame(width: 2, height: 2)
            .accessibilityElement()
            .accessibilityIdentifier("screenshot.ready")
            .accessibilityValue(readiness.summary)
            .accessibilityLabel(readiness.imagesAllLoaded ? "true" : "false")
            .allowsHitTesting(false)
    }
}

/// Counts a placeholder (shimmer / skeleton) as "loading" while it is on screen.
struct ScreenshotShimmerTracker: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { ScreenshotReadiness.shared.shimmerAppeared() }
            .onDisappear { ScreenshotReadiness.shared.shimmerDisappeared() }
    }
}

/// Reports an image view as pending, or a photo tile as empty, to `ScreenshotReadiness` while the condition holds.
struct ScreenshotImageTracker: ViewModifier {
    enum Kind { case pendingImage, emptyTile }
    let kind: Kind
    let active: Bool
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { report(active) }
            .onChange(of: active) { _, now in report(now) }
            .onDisappear { report(false) }
    }

    /// Forwards the state to the shared readiness model.
    private func report(_ value: Bool) {
        switch kind {
        case .pendingImage: ScreenshotReadiness.shared.setImagePending(token, value)
        case .emptyTile: ScreenshotReadiness.shared.setTileEmpty(token, value)
        }
    }
}
#endif

extension View {
    /// Screenshot mode only: counts this view as a not-yet-loaded image while `pending` is true.
    @ViewBuilder func screenshotImagePending(_ pending: Bool) -> some View {
        #if DEBUG
        if ScreenshotPrivacy.isActive { modifier(ScreenshotImageTracker(kind: .pendingImage, active: pending)) } else { self }
        #else
        self
        #endif
    }

    /// Screenshot mode only: counts this tile as "no photo" while `empty` is true.
    @ViewBuilder func screenshotTileEmpty(_ empty: Bool) -> some View {
        #if DEBUG
        if ScreenshotPrivacy.isActive { modifier(ScreenshotImageTracker(kind: .emptyTile, active: empty)) } else { self }
        #else
        self
        #endif
    }
}
