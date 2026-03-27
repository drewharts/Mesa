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
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @State private var selectedTab: FeedTab = .feed
    @State private var navigationPath = NavigationPath()

    private let userId: String

    /// Initializes the feed view for a specific user.
    init(userId: String) {
        self.userId = userId
        self._viewModel = StateObject(wrappedValue: PhotoFeedViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                feedTabHeader
                tabContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
            }
        }
        .task {
            await viewModel.loadFeed()
        }
    }

    // MARK: - Tab Header

    private var feedTabHeader: some View {
        HStack(spacing: 32) {
            FeedTabButton(title: "Feed", isSelected: selectedTab == .feed) {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .feed }
            }
            FeedTabButton(title: "Explore", isSelected: selectedTab == .explore) {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .explore }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .feed:
            feedContent
        case .explore:
            ExploreFeedView(viewModel: exploreViewModel, onPlaceTap: { placeId in
                navigationPath.append(placeId)
            })
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
                    PresentationService.shared.dismiss()
                    guard let currentUserId = userSession.currentUserId else { return }
                    userProfileNavigationVM.fetchAndSelectUser(userId: profileId, currentUserId: currentUserId)
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
                        onProfileTapped: { profileId in
                            PresentationService.shared.dismiss()
                            guard let currentUserId = userSession.currentUserId else { return }
                            userProfileNavigationVM.fetchAndSelectUser(userId: profileId, currentUserId: currentUserId)
                        }
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

}
