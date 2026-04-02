//
//  ProfileFavoritesPopupView.swift
//  loc
//
//  Unified popup view for favorites in external user profiles.
//  Does NOT trigger map display - shows favorites in a local sheet.
//  Follows the same pattern as ExternalUserListPopupView for consistent UX.
//

import SwiftUI

/// Displays favorite places for an external user profile in a local popup sheet.
struct ProfileFavoritesPopupView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel

    // Environment objects needed to flow through to PlaceDetailViewInNavigation
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var navigationPath = NavigationPath()

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
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
            }
        }
        .onAppear {
            navigationPath = NavigationPath()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("\(viewModel.user.firstName)'s Favorites")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Spacer()

                    HStack(alignment: .center, spacing: 12) {
                        Button(action: viewFavoritesOnMap) {
                            Image(systemName: "map")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 44, height: 44)

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 44, height: 44)
                    }
                }

                Text("\(viewModel.userFavorites.count) place\(viewModel.userFavorites.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, -8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .padding(.bottom, 28)
    }

    /// Dismisses the sheet and shows favorites on the map.
    private func viewFavoritesOnMap() {
        let navVM = userProfileNavigationVM
        mapDisplayCoordinatorVM.triggerExternalFavoritesOnMap(
            userId: viewModel.userId,
            userName: viewModel.user.fullName,
            userPhotoUrl: viewModel.user.profilePhotoURL?.absoluteString,
            favorites: viewModel.userFavorites,
            dismissProfile: { navVM.clearSelection() }
        )
        presentationMode.wrappedValue.dismiss()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingFavorites && viewModel.userFavorites.isEmpty {
            loadingView
        } else if viewModel.userFavorites.isEmpty {
            emptyView
        } else {
            ScrollView {
                gridView
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Text("Loading Favorites...")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text("No Favorites Yet")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            Text("This user hasn't added any favorite places yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var gridView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.lightweightFavorites, id: \.id) { place in
                PopupPlaceCard(
                    place: place,
                    preferExternalThumbnail: false,
                    onNavigate: { placeId in
                        navigationPath.append(placeId)
                        Task {
                            guard let place = try? await PlaceService.shared.fetchPlace(withId: placeId) else { return }
                            selectedPlaceVM.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
