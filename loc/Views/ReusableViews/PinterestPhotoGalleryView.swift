//
//  PinterestPhotoGalleryView.swift
//  loc
//
//  Pinterest-style photo gallery with swipe-down dismiss and smooth animations
//

import SwiftUI

struct PinterestPhotoGalleryView: View {
    let photos: [UIImage]
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
    
    init(photos: [UIImage], initialIndex: Int, isPresented: Binding<Bool>) {
        self.photos = photos
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
        ZStack {
            // Solid black background for true full-screen feel
            Color.black
                .opacity(backgroundOpacity)
                .onTapGesture {
                    dismissGallery()
                }

            VStack(spacing: 0) {
                // Header
                headerView

                // Photo content
                photoContent
                    .offset(y: dragOffset.height)
                    .scaleEffect(dragScale)
                    .gesture(dismissDragGesture)

                // Page indicator
                if photos.count > 1 {
                    pageIndicator
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Spacer()

            // Photo counter - centered, minimal pill design
            if photos.count > 1 {
                Text("\(currentIndex + 1)/\(photos.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(Capsule())
            }

            Spacer()

            // Close button - minimal modern style, top right
            Button(action: dismissGallery) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56) // Account for safe area (notch)
        .padding(.bottom, 8)
        .opacity(isDragging ? 0.3 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isDragging)
    }
    
    // MARK: - Photo Content
    
    private var photoContent: some View {
        Group {
            if photos.count > 1 {
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        InteractiveImageView(image: photo)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else if let photo = photos.first {
                InteractiveImageView(image: photo)
            }
        }
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<photos.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentIndex ? 1.0 : 0.8)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
        .padding(.vertical, 16)
        .padding(.bottom, 20) // Account for home indicator
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

// MARK: - Interactive Image View

/// Image view with pinch-to-zoom and double-tap zoom
private struct InteractiveImageView: View {
    let image: UIImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(magnificationGesture)
                .gesture(scale > 1 ? panGesture(in: geometry) : nil)
                .onTapGesture(count: 2) {
                    handleDoubleTap()
                }
                .onAppear {
                    // Reset zoom and pan state when view appears
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
        }
        .clipped()
    }
    
    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = min(max(newScale, minScale), maxScale)
                
                if scale <= minScale {
                    offset = .zero
                }
            }
            .onEnded { _ in
                lastScale = scale
                
                if scale < minScale {
                    withAnimation(.spring(response: 0.3)) {
                        scale = minScale
                        offset = .zero
                    }
                    lastScale = minScale
                }
            }
    }
    
    private func panGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let newOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                
                // Calculate bounds based on scale
                let imageSize = calculateImageSize(in: geometry)
                let scaledSize = CGSize(
                    width: imageSize.width * scale,
                    height: imageSize.height * scale
                )
                
                let maxX = max(0, (scaledSize.width - geometry.size.width) / 2)
                let maxY = max(0, (scaledSize.height - geometry.size.height) / 2)
                
                offset = CGSize(
                    width: min(max(newOffset.width, -maxX), maxX),
                    height: min(max(newOffset.height, -maxY), maxY)
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    private func handleDoubleTap() {
        withAnimation(.spring(response: 0.3)) {
            if scale > minScale {
                scale = minScale
                offset = .zero
                lastScale = minScale
                lastOffset = .zero
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }
    
    private func calculateImageSize(in geometry: GeometryProxy) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = geometry.size.width / geometry.size.height
        
        if imageAspect > containerAspect {
            let width = geometry.size.width
            return CGSize(width: width, height: width / imageAspect)
        } else {
            let height = geometry.size.height
            return CGSize(width: height * imageAspect, height: height)
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
                        photos: [UIImage(systemName: "photo")!],
                        initialIndex: 0,
                        isPresented: $isPresented
                    )
                }
            }
        }
    }
    
    return PreviewWrapper()
}
