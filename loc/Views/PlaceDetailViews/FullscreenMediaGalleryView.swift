//
//  FullscreenMediaGalleryView.swift
//  loc
//
//  Unified fullscreen viewer for swiping between photos and videos in a post.
//

import SwiftUI

struct FullscreenMediaGalleryView: View {
    let mediaItems: [PostMediaItem]
    let initialIndex: Int

    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    init(mediaItems: [PostMediaItem], initialIndex: Int) {
        self.mediaItems = mediaItems
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                    mediaPage(for: item, at: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .offset(y: dragOffset)

            headerOverlay
            footerOverlay
        }
        .gesture(dismissDragGesture)
        .statusBarHidden()
    }

    // MARK: - Media Pages

    /// Renders the appropriate media page based on item type.
    @ViewBuilder
    private func mediaPage(for item: PostMediaItem, at index: Int) -> some View {
        switch item.type {
        case .image:
            AsyncInteractiveImageView(imageURL: item.url)
        case .video:
            if let videoURL = URL(string: item.url) {
                GalleryVideoPlayerView(url: videoURL, isActive: currentIndex == index)
            }
        }
    }

    // MARK: - Header

    private var headerOverlay: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                Text("\(currentIndex + 1)/\(mediaItems.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Footer

    private var footerOverlay: some View {
        VStack {
            Spacer()

            if mediaItems.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<mediaItems.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Dismiss Gesture

    /// Swipe-down gesture to dismiss the gallery.
    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 100 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        dragOffset = 0
                    }
                }
            }
    }
}
