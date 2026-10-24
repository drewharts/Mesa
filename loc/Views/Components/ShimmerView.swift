//
//  ShimmerView.swift
//  loc
//
//  Reusable modern skeleton/shimmer loading system.
//  - ShimmerView: a filled skeleton block with a soft highlight sweep.
//  - SkeletonBlock: rounded placeholder shape (use to mirror real layouts).
//  - .shimmering(): modifier that sweeps a highlight over any view (works with .redacted).
//  - .skeleton(_:): redacts real layout with placeholders + shimmer while loading.
//  - DelayedAppear: only shows its content after a short delay, avoiding flashes on fast loads.
//  - InlineLoadingIndicator: subtle small spinner for buttons / pagination.
//  Respects Reduce Motion (static placeholder, no sweep) and adapts to dark mode.
//

import SwiftUI

enum SkeletonStyle {
    /// Base fill for placeholder shapes; adapts to light/dark mode.
    static let base = Color(.systemGray5)
    /// Highlight that sweeps across placeholders.
    static let highlight = Color(.systemGray6)
}

/// Sweeping highlight overlay used by every skeleton in the app.
struct ShimmerModifier: ViewModifier {
    var active: Bool = true
    var duration: Double = 1.25
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    @ViewBuilder
    func body(content: Content) -> some View {
        if !active || reduceMotion {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        let w = geo.size.width
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white.opacity(0), location: 0),
                                .init(color: .white.opacity(0.35), location: 0.5),
                                .init(color: .white.opacity(0), location: 1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(w * 0.6, 80))
                        .rotationEffect(.degrees(12))
                        .offset(x: phase * (w + max(w * 0.6, 80)))
                    }
                    .allowsHitTesting(false)
                )
                .clipped()
                .onAppear {
                    phase = -1
                    withAnimation(.easeInOut(duration: duration).delay(0.15).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

extension View {
    /// Sweeps a soft highlight across this view.
    func shimmering(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }

    /// Turns a real layout into a shimmering placeholder while `isLoading` is true.
    func skeleton(_ isLoading: Bool) -> some View {
        self
            .redacted(reason: isLoading ? .placeholder : [])
            .modifier(SkeletonPulse(active: isLoading))
            .allowsHitTesting(!isLoading)
    }

    /// Short fade used when real content replaces a skeleton.
    func loadFadeIn() -> some View {
        transition(.opacity.animation(.easeOut(duration: 0.22)))
    }
}

/// Gentle opacity pulse for redacted real layouts (no overlay, so it never tints backgrounds).
struct SkeletonPulse: ViewModifier {
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(active && !reduceMotion && dim ? 0.55 : 1)
            .onAppear {
                guard active, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

/// Rounded placeholder block.
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(SkeletonStyle.base)
            .frame(width: width, height: height)
            .shimmering()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// Filled placeholder that fills its frame. Kept for existing call sites:
/// callers frame it and clip it to a shape.
struct ShimmerView: View {
    var body: some View {
        Rectangle()
            .fill(SkeletonStyle.base)
            .shimmering()
    }
}

/// Shows its content only after a short delay, so fast loads never flash a skeleton.
struct DelayedAppear<Content: View>: View {
    var delay: Double = 0.15
    @ViewBuilder var content: () -> Content
    @State private var visible = false

    var body: some View {
        ZStack {
            if visible {
                content().transition(.opacity)
            } else {
                Color.clear
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.2)) { visible = true }
        }
    }
}

/// Subtle small spinner for inline / button / pagination loading.
struct InlineLoadingIndicator: View {
    var tint: Color = .secondary
    var body: some View {
        ProgressView()
            .controlSize(.small)
            .tint(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .accessibilityLabel("Loading")
    }
}

/// Generic list-row skeleton (thumbnail + two lines) used by lists/search/feed.
struct SkeletonRow: View {
    var thumbSize: CGFloat = 52
    var body: some View {
        HStack(spacing: 12) {
            SkeletonBlock(width: thumbSize, height: thumbSize, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 160, height: 14, cornerRadius: 6)
                SkeletonBlock(width: 100, height: 11, cornerRadius: 5)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Stack of skeleton rows, delayed to avoid flashing on fast loads.
struct SkeletonList: View {
    var rows: Int = 5
    var body: some View {
        DelayedAppear {
            VStack(spacing: 16) {
                ForEach(0..<rows, id: \.self) { _ in SkeletonRow() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading")
        }
    }
}

/// Grid of card skeletons (lists / photo grids).
struct SkeletonCardGrid: View {
    var count: Int = 4
    var height: CGFloat = 140
    var body: some View {
        DelayedAppear {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(0..<count, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: height, cornerRadius: 14)
                        SkeletonBlock(width: 90, height: 12, cornerRadius: 5)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading")
        }
    }
}

/// Skeleton for the profile tab preview grid (3 columns x 2 rows of 90pt tiles),
/// mirroring ProfilePlacesPreviewGrid so the swap to real content doesn't jump.
struct SkeletonProfilePreviewGrid: View {
    var count: Int = 6
    var body: some View {
        DelayedAppear {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<count, id: \.self) { _ in
                    SkeletonBlock(height: 90, cornerRadius: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading")
        }
        .frame(minHeight: 188, alignment: .top)
    }
}

#Preview {
    VStack(spacing: 16) {
        SkeletonRow()
        SkeletonCardGrid()
        InlineLoadingIndicator()
    }
    .padding()
}
