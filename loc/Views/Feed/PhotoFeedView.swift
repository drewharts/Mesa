//
//  PhotoFeedView.swift
//  loc
//
//  SMART View: Photo feed showing review photos from followed users.
//  Single Responsibility: Present scrollable photo feed with pull-to-refresh and pagination.
//

import SwiftUI

/// Tab options for the feed screen.
enum FeedTab {
    case feed
    case explore
}

struct PhotoFeedView: View {
    @StateObject private var viewModel: PhotoFeedViewModel
    @StateObject private var exploreViewModel = ExploreViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: FeedTab = .feed

    private let userId: String
    private let onNavigateToProfile: (String) -> Void
    private let onNavigateToPlace: (String) -> Void

    /// Initializes the feed view with callbacks for profile and place navigation.
    init(
        userId: String,
        onNavigateToProfile: @escaping (String) -> Void = { _ in },
        onNavigateToPlace: @escaping (String) -> Void = { _ in }
    ) {
        self.userId = userId
        self.onNavigateToProfile = onNavigateToProfile
        self.onNavigateToPlace = onNavigateToPlace
        self._viewModel = StateObject(wrappedValue: PhotoFeedViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                feedTabHeader
                tabContent
            }
            .navigationTitle(selectedTab == .feed ? "Feed" : "Explore")
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

    // MARK: - Tab Header

    private var feedTabHeader: some View {
        HStack(spacing: 24) {
            FeedTabButton(title: "Feed", isSelected: selectedTab == .feed) {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .feed }
            }
            FeedTabButton(title: "Explore", isSelected: selectedTab == .explore) {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .explore }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .feed:
            feedContent
        case .explore:
            ExploreFeedView(viewModel: exploreViewModel, onPlaceTap: onNavigateToPlace)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var feedContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.feedItems.isEmpty {
            emptyFeedContent
        } else {
            feedList
        }
    }

    // MARK: - Empty Feed

    private var emptyFeedContent: some View {
        VStack(spacing: 0) {
            recommendedSection
            emptyState
                .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Recommended Users

    @ViewBuilder
    private var recommendedSection: some View {
        let vm = viewModel.recommendedUsersViewModel
        if !vm.isDismissed {
            RecommendedUsersSection(
                users: vm.recommendedUsers,
                followStates: vm.followStates,
                isLoading: vm.isLoading,
                onFollowTap: { profileId in
                    Task { await vm.toggleFollow(profileId: profileId) }
                },
                onProfileTap: { profileId in
                    onNavigateToProfile(profileId)
                },
                onDismiss: { vm.dismiss() }
            )
        }
    }

    // MARK: - Feed List

    /// Index after which the recommended section is inserted (0-based).
    private var recommendedInsertionIndex: Int {
        min(2, viewModel.feedItems.count - 1)
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.feedItems.enumerated()), id: \.element.id) { index, item in
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

                    if index == recommendedInsertionIndex {
                        recommendedSection
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
