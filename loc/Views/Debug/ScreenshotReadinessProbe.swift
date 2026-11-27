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
#endif
