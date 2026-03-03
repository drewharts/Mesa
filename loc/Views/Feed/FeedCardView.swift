//
//  FeedCardView.swift
//  loc
//
//  DUMB Component: Flip container for a feed card (front = photo, back = map).
//  Single Responsibility: Manage 3D rotation between front and back faces,
//  and present fullscreen gallery on pinch-to-zoom.
//

import SwiftUI

struct FeedCardView: View {
    let item: FeedItem
    let isFlipped: Bool
    let currentUserId: String
    let currentUserProfile: ProfileData?
    let onFlip: () -> Void
    let onCommentCountChanged: (Int) -> Void
    let onProfileTapped: (String) -> Void

    @State private var fullscreenIndex: Int?
    @State private var showComments = false

    var body: some View {
        Group {
            if isFlipped {
                FeedCardBackView(item: item)
                    .rotation3DEffect(
                        .degrees(0),
                        axis: (x: 0, y: 1, z: 0)
                    )
            } else {
                FeedCardFrontView(
                    item: item,
                    onComment: { showComments = true },
                    onZoom: { index in fullscreenIndex = index },
                    onProfileTapped: { onProfileTapped(item.userId) }
                )
                .rotation3DEffect(
                    .degrees(0),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.5)) {
                onFlip()
            }
        }
        .fullScreenCover(item: fullscreenBinding) { wrapper in
            FullscreenMediaGalleryView(
                mediaItems: item.imageUrls.map { PostMediaItem(imageUrl: $0) },
                initialIndex: wrapper.index
            )
        }
        .sheet(isPresented: $showComments) {
            FeedCommentsSheet(
                item: item,
                currentUserId: currentUserId,
                currentUserProfile: currentUserProfile,
                onDismissCount: { count in
                    onCommentCountChanged(count)
                },
                onProfileTapped: onProfileTapped
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Fullscreen Binding

    private var fullscreenBinding: Binding<FullscreenIndexWrapper?> {
        Binding(
            get: {
                guard let index = fullscreenIndex else { return nil }
                return FullscreenIndexWrapper(index: index)
            },
            set: { newValue in
                fullscreenIndex = newValue?.index
            }
        )
    }
}

// MARK: - Identifiable Wrapper

/// Wraps an index value to satisfy Identifiable for fullScreenCover(item:).
private struct FullscreenIndexWrapper: Identifiable {
    let index: Int
    var id: Int { index }
}
