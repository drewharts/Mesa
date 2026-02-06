//
//  PinterestPhotoGalleryView.swift
//  loc
//
//  Pinterest-style photo gallery with swipe-down dismiss and smooth animations
//

import SwiftUI

struct PinterestPhotoGalleryView: View {
    let photoURLs: [String]
    let initialIndex: Int
    @Binding var isPresented: Bool

    // MARK: - State
    @State private var currentIndex: Int
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var imageScale: CGFloat = 1.0

    // MARK: - Constants
    private let dismissThreshold: CGFloat = 150
    private let velocityThreshold: CGFloat = 800

    init(photoURLs: [String], initialIndex: Int, isPresented: Binding<Bool>) {
        self.photoURLs = photoURLs
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }

    // MARK: - Computed Properties

    /// Background opacity decreases as user drags
    private var backgroundOpacity: Double {
        let progress = min(abs(dragOffset.height) / 300, 1.0)
        return 1.0 - (progress * 0.6)
    }

    /// Scale decreases slightly as user drags for depth effect
    private var dragScale: CGFloat {
        let progress = min(abs(dragOffset.height) / 500, 1.0)
        return 1.0 - (progress * 0.15)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - tappable to dismiss
                Color.black
                    .opacity(backgroundOpacity)
                    .onTapGesture { dismissGallery() }

                // Photo content with page indicator
                VStack(spacing: 0) {
                    photoContent
                        .offset(y: dragOffset.height)
                        .scaleEffect(dragScale)
                        .gesture(dismissDragGesture)

                    if photoURLs.count > 1 {
                        pageIndicator(safeAreaBottom: geometry.safeAreaInsets.bottom)
                    }
                }

                // Header overlay - positioned at top, independent of content
                VStack {
                    headerView(safeAreaTop: geometry.safeAreaInsets.top)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private func headerView(safeAreaTop: CGFloat) -> some View {
        ZStack {
            // Counter - truly centered (independent of X button)
            if photoURLs.count > 1 {
                Text("\(currentIndex + 1)/\(photoURLs.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            // X button - pinned to trailing edge
            HStack {
                Spacer()
                Button(action: dismissGallery) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, safeAreaTop + 16)
        .opacity(isDragging ? 0.3 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isDragging)
    }

    // MARK: - Photo Content

    private var photoContent: some View {
        Group {
            if photoURLs.count > 1 {
                TabView(selection: $currentIndex) {
                    ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, url in
                        AsyncInteractiveImageView(imageURL: url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else if let url = photoURLs.first {
                AsyncInteractiveImageView(imageURL: url)
            }
        }
    }

    // MARK: - Page Indicator

    private func pageIndicator(safeAreaBottom: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<photoURLs.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 12)
        .padding(.bottom, max(safeAreaBottom, 16))
        .opacity(isDragging ? 0.3 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isDragging)
    }

    // MARK: - Gestures

    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow vertical dragging for dismiss
                isDragging = true
                dragOffset = CGSize(width: 0, height: value.translation.height)
            }
            .onEnded { value in
                isDragging = false

                let verticalVelocity = abs(value.velocity.height)
                let verticalTranslation = abs(value.translation.height)

                // Dismiss if dragged far enough or flicked fast enough
                if verticalTranslation > dismissThreshold || verticalVelocity > velocityThreshold {
                    dismissWithAnimation(velocity: value.velocity.height)
                } else {
                    // Bounce back
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    // MARK: - Actions

    private func dismissGallery() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
    }

    private func dismissWithAnimation(velocity: CGFloat) {
        // Animate off screen in direction of swipe
        let targetOffset: CGFloat = velocity > 0 ? 1000 : -1000

        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: 0, height: targetOffset)
        }

        // Dismiss after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            ZStack {
                Color.gray

                if isPresented {
                    PinterestPhotoGalleryView(
                        photoURLs: ["https://example.com/photo.jpg"],
                        initialIndex: 0,
                        isPresented: $isPresented
                    )
                }
            }
        }
    }

    return PreviewWrapper()
}
