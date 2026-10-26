//
//  ExternalUserProfileContentView.swift
//  loc
//
//  Content view for external user profiles using ExternalUserProfileViewModel.
//  This view is presented inside ExternalUserProfileViewWrapper which owns the @StateObject.
//

import SwiftUI

struct ExternalUserProfileContentView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode

    @State private var showFollowers = false
    @State private var showFollowing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Picture (left) + name/follow counts (right), Follow button below —
                // condensed horizontal header so more content is visible without scrolling.
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        UserProfileProfilePictureView(profilePhotoURL: viewModel.user.profilePhotoURL)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Text(viewModel.user.fullName)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)

                                ProfileSocialLinksRow(
                                    instagramUsername: viewModel.user.instagramUsername,
                                    tiktokUsername: viewModel.user.tiktokUsername
                                )
                            }

                            // Clickable Followers/Following/Places counts
                            ProfileFollowCountsView(
                                data: .external(
                                    followers: viewModel.followers,
                                    following: viewModel.followingCount,
                                    places: viewModel.totalPlacesCount
                                ),
                                onFollowersTap: { showFollowers = true },
                                onFollowingTap: { showFollowing = true },
                                hideFollowing: viewModel.isCuratedProfile
                            )

                            if !viewModel.isCuratedProfile {
                                TasteMatchBadge(
                                    match: viewModel.tasteMatch,
                                    isLoading: viewModel.isLoadingTasteMatch
                                )
                                .padding(.top, 4)
                            }
                        }

                        Spacer(minLength: 0)
                    }

                    Button(action: {
                        guard let currentUserId = userSession.currentUserId else { return }
                        viewModel.toggleFollowUser(currentUserId: currentUserId) { success, newFollowingState in
                            if success {
                                profileVM.socialViewModel.updateFollowingState(
                                    userId: viewModel.userId,
                                    isFollowing: newFollowingState
                                )
                            }
                        }
                    }) {
                        Text(viewModel.isFollowing ? "Following" : "Follow")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(viewModel.isFollowing ? .primary : .white)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.isFollowing ? Color(.systemGray5) : Color.blue)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, 20)

                // Content section
                VStack(spacing: 20) {
                    if viewModel.isEmptyProfile {
                        ExternalProfileEmptyStateCard(
                            firstName: viewModel.user.firstName,
                            isFollowing: viewModel.isFollowing,
                            onShare: {
                                ServiceContainer.shared.placeShareService.shareProfile(viewModel.user)
                            }
                        )
                        .padding(.top, 24)
                        .transition(.opacity)
                    } else if !viewModel.hasLoadedInitialData && viewModel.userLists.isEmpty && viewModel.userFavorites.isEmpty {
                        ExternalProfileLoadingSkeleton()
                            .padding(.top, 16)
                    } else {
                        // Favorites & Reviews (hidden for curated/brand profiles)
                        if !viewModel.isCuratedProfile {
                            ExternalUserProfileFavoritesReviewsView(viewModel: viewModel)
                                .padding(.top, 16)
                        }

                        // Place Lists
                        ExternalUserProfileListsView(viewModel: viewModel, placeLists: viewModel.userLists)
                            .padding(.top, viewModel.isCuratedProfile ? 16 : 0)
                    }

                    Spacer(minLength: 50)
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.hasLoadedInitialData)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(
            Group {
                NavigationLink(
                    destination: ProfileFollowersListView(viewModel: viewModel)
                        .environmentObject(profileVM)
                        .environmentObject(detailPlaceVM)
                        .environmentObject(userSession)
                        .environmentObject(selectedPlaceVM)
                        .environmentObject(userProfileNavigationVM)
                        .environmentObject(mapDisplayCoordinatorVM)
                        .environmentObject(locationManager)
                        .environmentObject(dataManager),
                    isActive: $showFollowers
                ) {
                    EmptyView()
                }

                if !viewModel.isCuratedProfile {
                    NavigationLink(
                        destination: ProfileFollowingListView(viewModel: viewModel)
                            .environmentObject(profileVM)
                            .environmentObject(detailPlaceVM)
                            .environmentObject(userSession)
                            .environmentObject(selectedPlaceVM)
                            .environmentObject(userProfileNavigationVM)
                            .environmentObject(mapDisplayCoordinatorVM)
                            .environmentObject(locationManager)
                            .environmentObject(dataManager),
                        isActive: $showFollowing
                    ) {
                        EmptyView()
                    }
                }
            }
        )
        .alert("Follow Error", isPresented: $viewModel.showFollowError) {
            Button("OK") {
                viewModel.showFollowError = false
            }
        } message: {
            Text(viewModel.followErrorMessage)
        }
        .alert("Follow Error", isPresented: Binding(
            get: { profileVM.socialViewModel.showFollowError },
            set: { profileVM.socialViewModel.showFollowError = $0 }
        )) {
            Button("OK") {
                profileVM.socialViewModel.showFollowError = false
            }
        } message: {
            Text(profileVM.socialViewModel.followErrorMessage)
        }
    }
}

// MARK: - Empty state

/// Friendly card shown when another user's profile has nothing saved yet,
/// so the page feels intentional instead of a stack of empty containers.
struct ExternalProfileEmptyStateCard: View {
    let firstName: String
    let isFollowing: Bool
    let onShare: () -> Void

    private var name: String { firstName.isEmpty ? "They" : firstName }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 72, height: 72)
                Image(systemName: "map")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 6) {
                Text("\(name) is just getting started")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(isFollowing
                     ? "You'll see their favorite spots and lists here as soon as they save some."
                     : "No saved places yet. Follow \(firstName.isEmpty ? "them" : firstName) to see their spots and lists as soon as they add them.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                emptyHint(icon: "heart", text: "Favorites")
                emptyHint(icon: "list.bullet", text: "Lists")
                emptyHint(icon: "star", text: "Reviews")
            }
            .padding(.top, 2)

            Button(action: onShare) {
                Label("Share profile", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().stroke(Color.blue.opacity(0.4), lineWidth: 1))
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
    }

    private func emptyHint(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.caption)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(.systemBackground)))
    }
}

/// Placeholder shown while a profile's content is loading (own and other profiles).
struct ExternalProfileLoadingSkeleton: View {
    var body: some View {
        DelayedAppear {
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 140, height: 14, cornerRadius: 7)
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonBlock(height: 90, cornerRadius: 14)
                    }
                }
                SkeletonBlock(width: 110, height: 14, cornerRadius: 7)
                HStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { _ in
                        SkeletonBlock(height: 140, cornerRadius: 16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading profile")
        }
    }
}
