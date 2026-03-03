//
//  PhotoFeedView.swift
//  loc
//
//  SMART View: Photo feed showing review photos from followed users.
//  Single Responsibility: Present scrollable photo feed with pull-to-refresh and pagination.
//

import SwiftUI

struct PhotoFeedView: View {
    @StateObject private var viewModel: PhotoFeedViewModel
    @Environment(\.dismiss) private var dismiss

    private let userId: String
    private let onNavigateToProfile: (String) -> Void

    /// Initializes the feed view for a specific user with an optional profile navigation callback.
    init(userId: String, onNavigateToProfile: @escaping (String) -> Void = { _ in }) {
        self.userId = userId
        self.onNavigateToProfile = onNavigateToProfile
        self._viewModel = StateObject(wrappedValue: PhotoFeedViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack {
            feedContent
                .navigationTitle("Feed")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        dismissButton
                    }
                }
        }
        .task {
            await viewModel.loadFeed()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var feedContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.feedItems.isEmpty {
            emptyState
        } else {
            feedList
        }
    }

    // MARK: - Feed List

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.feedItems) { item in
                    FeedCardView(
                        item: item,
                        isFlipped: viewModel.flippedCardId == item.id,
                        currentUserId: userId,
                        currentUserProfile: viewModel.currentUserProfile,
                        onFlip: { viewModel.toggleFlip(for: item.id) },
                        onCommentCountChanged: { count in
                            viewModel.updateCommentCount(for: item.id, count: count)
                        },
                        onProfileTapped: onNavigateToProfile
                    )
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: item)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Photos Yet",
            systemImage: "photo.on.rectangle.angled",
            description: Text("Follow people to see their photos here")
        )
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
}
