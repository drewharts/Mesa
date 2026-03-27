//
//  FeedCardView.swift
//  loc
//
//  DUMB Component: Feed card showing a review with photos.
//  Single Responsibility: Present photo card with comment sheet and fullscreen gallery.
//

import SwiftUI

struct FeedCardView: View {
    let item: FeedItem
    let currentUserId: String
    let currentUserProfile: ProfileData?
    let onCommentCountChanged: (Int) -> Void
    let onProfileTapped: (String) -> Void
    let onPlaceTapped: (String) -> Void

    @State private var fullscreenIndex: Int?
    @State private var showComments = false

    var body: some View {
        FeedCardFrontView(
            item: item,
            onComment: { showComments = true },
            onZoom: { index in fullscreenIndex = index },
            onProfileTapped: { onProfileTapped(item.userId) },
            onPlaceTapped: { onPlaceTapped(item.placeId) }
        )
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
