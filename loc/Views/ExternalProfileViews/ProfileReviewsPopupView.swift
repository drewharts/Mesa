//
//  ProfileReviewsPopupView.swift
//  loc
//
//  Unified popup view for reviews in external user profiles.
//  Does NOT trigger map display - shows reviews in a local sheet.
//  Follows the same pattern as ExternalUserListPopupView for consistent UX.
//

import SwiftUI

/// Displays paginated reviewed places for an external user profile in a local popup sheet.
struct ProfileReviewsPopupView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel

    // Environment objects needed to flow through to PlaceDetailViewInNavigation
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var navigationPath = NavigationPath()
    @State private var isLoadingMore = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                header
                content
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250)
            }
        }
        .onAppear {
            navigationPath = NavigationPath()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Profile")
                    }
                    .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 4) {
                Text("\(viewModel.user.firstName)'s Reviews")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text("\(viewModel.totalReviewedPlacesCount) place\(viewModel.totalReviewedPlacesCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingReviewedPlaces && viewModel.lightweightReviewedPlaces.isEmpty {
            loadingView
        } else if viewModel.lightweightReviewedPlaces.isEmpty {
            emptyView
        } else {
            ScrollView {
                gridView

                if isLoadingMore {
                    loadingMoreIndicator
                }
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Text("Loading Reviews...")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "star.bubble")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("No Reviews Yet")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            Text("This user hasn't reviewed any places yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var gridView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(viewModel.lightweightReviewedPlaces.enumerated()), id: \.element.id) { index, place in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: false,
                    allowDelete: false,
                    onNavigate: { placeId in
                        navigationPath.append(placeId)
                    }
                )
                .onAppear {
                    triggerPaginationIfNeeded(index: index)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var loadingMoreIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }

    // MARK: - Pagination

    /// Triggers loading more reviews when approaching the end of the list.
    private func triggerPaginationIfNeeded(index: Int) {
        guard index == viewModel.lightweightReviewedPlaces.count - 3,
              viewModel.hasMoreReviews,
              !isLoadingMore else { return }

        isLoadingMore = true
        Task {
            await viewModel.loadMoreReviews()
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }
}
