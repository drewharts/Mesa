//
//  CityDetailSheet.swift
//  loc
//
//  Sheet displaying stats, lists, top places, and active users for a city.
//

import CoreLocation
import SwiftUI

/// City detail sheet showing an overview of a city from map annotation tap or search.
struct CityDetailSheet: View {
    let cityName: String
    let coordinate: CLLocationCoordinate2D
    @StateObject private var viewModel: CityDetailViewModel
    @ObservedObject private var presentationService = PresentationService.shared
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var userProfileNavigationViewModel: UserProfileNavigationViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    init(cityName: String, coordinate: CLLocationCoordinate2D, annotation: CityAnnotation? = nil) {
        self.cityName = cityName
        self.coordinate = coordinate
        self._viewModel = StateObject(wrappedValue: CityDetailViewModel(
            cityName: cityName,
            coordinate: coordinate,
            annotation: annotation
        ))
    }

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(cityName)
                        .font(.title)
                        .fontWeight(.bold)

                    statsBar

                    listsSection
                    topPlacesSection
                    tiktoksSection
                    peopleSection

                    if viewModel.isLoading && viewModel.hasNoContent {
                        loadingView
                    }
                    emptyStateView
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CityDetailDestination.self) { destination in
                switch destination {
                case .allLists:
                    CityAllListsView(
                        lists: viewModel.lists,
                        placeColors: $viewModel.placeColors,
                        onListTap: { list in
                            viewModel.handleListTap(list)
                        }
                    )
                case .allPlaces:
                    CityAllPlacesView(
                        places: viewModel.topPlaces,
                        onPlaceTap: { place in
                            viewModel.handlePlaceTap(placeId: place.id)
                        }
                    )
                case .allPhotos:
                    CityAllPhotosView(
                        viewModel: viewModel,
                        onPhotoTap: { photo in
                            viewModel.handlePlaceTap(placeId: photo.placeId)
                        }
                    )
                case .allVideos:
                    CityAllVideosView(
                        viewModel: viewModel,
                        onVideoTap: { tiktok in
                            viewModel.handlePlaceTap(placeId: tiktok.placeId)
                        }
                    )
                case .listDetail(let listId, let listName, let creatorId, let creatorName, let creatorPhotoUrl):
                    CityListDetailView(
                        listId: listId,
                        listName: listName,
                        creatorId: creatorId,
                        creatorName: creatorName,
                        creatorPhotoUrl: creatorPhotoUrl,
                        onPlaceTap: { placeId in
                            viewModel.handlePlaceTap(placeId: placeId)
                        },
                        onCreatorTap: { userId in
                            viewModel.handleUserTap(
                                userId: userId,
                                currentUserId: userSession.currentUserId
                            )
                        }
                    )
                case .placeDetail(let placeId):
                    PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 0, shouldAnimateMap: true)
                case .userProfile(let userId):
                    CityUserProfileView(userId: userId)
                        .id(userId)
                }
            }
            .task {
                if let userId = profileViewModel.user?.id {
                    await viewModel.loadContent(userId: userId)
                }
            }
            .onReceive(presentationService.$pendingPlaceNavigation.compactMap { $0 }) { placeId in
                viewModel.handlePlaceTap(placeId: placeId)
                presentationService.pendingPlaceNavigation = nil
            }
        }
    }

    // MARK: - Stats Bar

    /// Horizontal stats bar showing spots, reviews, friends, and reviewed counts.
    @ViewBuilder
    private var statsBar: some View {
        if viewModel.hasLoadedStats {
            HStack(spacing: 0) {
                statItem(icon: "mappin.circle.fill", count: viewModel.placeCount, label: "Spots", color: .blue)
                Spacer()
                statItem(icon: "star.bubble.fill", count: viewModel.reviewCount, label: "Reviews", color: .orange)
                Spacer()
                statItem(icon: "person.2.fill", count: viewModel.friendCount, label: "People", color: .green)
                Spacer()
                statItem(icon: "checkmark.seal.fill", count: viewModel.reviewedPlaceCount, label: "Reviewed", color: .purple)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    /// Single stat item with icon, count, and label.
    private func statItem(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Loading

    /// Loading spinner shown while content is being fetched.
    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.top, 40)
            Spacer()
        }
    }

    // MARK: - Lists Section

    /// Horizontal scrolling row of list tiles with "See All" header.
    @ViewBuilder
    private var listsSection: some View {
        if !viewModel.lists.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button { viewModel.navigateToAllLists() } label: {
                    HStack {
                        Text("Lists")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.lists, id: \.list_id) { list in
                            CityListTile(
                                list: list,
                                places: list.places,
                                placeColors: $viewModel.placeColors,
                                onTap: {
                                    viewModel.handleListTap(list)
                                }
                            )
                            .frame(width: 160)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Top Places Section

    /// Horizontal scrolling row of place tiles with "See All" header.
    @ViewBuilder
    private var topPlacesSection: some View {
        if !viewModel.topPlaces.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button { viewModel.navigateToAllPlaces() } label: {
                    HStack {
                        Text("Popular Places")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.topPlaces) { place in
                            CityPlaceTile(place: place, onTap: {
                                viewModel.handlePlaceTap(placeId: place.id)
                            })
                            .frame(width: 160)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Videos Section

    /// Horizontal scrolling row of TikTok video tiles with "See All" header.
    @ViewBuilder
    private var tiktoksSection: some View {
        if !viewModel.tiktoks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button { viewModel.navigateToAllVideos() } label: {
                    HStack {
                        Text("Videos")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.tiktoks) { tiktok in
                            CityTikTokTile(tiktok: tiktok, onTap: {
                                viewModel.handlePlaceTap(placeId: tiktok.placeId)
                            })
                            .frame(width: 160)
                        }
                    }
                }
            }
        }
    }

    // MARK: - People Section

    /// Horizontal scrolling row of user tiles with follow buttons.
    @ViewBuilder
    private var peopleSection: some View {
        if !viewModel.activeUsers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("People")
                    .font(.title3)
                    .fontWeight(.bold)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.activeUsers) { user in
                            CityUserTile(
                                user: user,
                                isFollowing: user.isFollowing,
                                isCurrentUser: user.id == userSession.currentUserId,
                                onTap: {
                                    viewModel.handleUserTap(
                                        userId: user.id,
                                        currentUserId: userSession.currentUserId
                                    )
                                },
                                onFollow: {
                                    viewModel.toggleFollow(userId: user.id)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    /// Shown when no lists, places, or users are found for the city.
    @ViewBuilder
    private var emptyStateView: some View {
        if !viewModel.isLoading && viewModel.hasNoContent {
            VStack(spacing: 8) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No details yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        }
    }
}
