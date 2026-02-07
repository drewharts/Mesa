//
//  ExternalUserLightweightListPopupView.swift
//  loc
//
//  Displays external user's list popup when viewing from the map.
//  Uses ExternalListPopupViewModel for self-contained data loading.
//

import SwiftUI

/// Displays an external user's list popup when viewing from the map.
struct ExternalUserLightweightListPopupView: View {
    @StateObject var viewModel: ExternalListPopupViewModel
    let showBackToProfileButton: Bool

    // Environment objects needed to flow through to PlaceDetailViewInNavigation
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    /// Observed for pending place navigation when map annotation is tapped while sheet is open.
    @ObservedObject private var presentationService = PresentationService.shared

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                popupHeader
                popupContent
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250)
            }
        }
        .onChange(of: presentationService.pendingPlaceNavigation) { oldValue, newValue in
            // When map annotation is tapped while list sheet is open, navigate to that place
            if let placeId = newValue {
                navigationPath.append(placeId)
                presentationService.pendingPlaceNavigation = nil
            }
        }
        .onAppear {
            navigationPath = NavigationPath()
        }
        .task {
            await viewModel.loadPlacesIfNeeded()
        }
    }

    // MARK: - Popup Header

    private var popupHeader: some View {
        VStack(spacing: 12) {
            HStack {
                if showBackToProfileButton {
                    backToProfileButton
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 4) {
                Text(viewModel.currentList.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text("\(viewModel.currentList.place_count) place\(viewModel.currentList.place_count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 10)
    }

    private var backToProfileButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .foregroundColor(.primary)
        }
    }

    // MARK: - Popup Content

    @ViewBuilder
    private var popupContent: some View {
        if viewModel.lists.count > 1 {
            multipleListsTabView
        } else {
            singleListScrollView
        }
    }

    private var multipleListsTabView: some View {
        TabView(selection: Binding(
            get: { viewModel.currentListIndex },
            set: { viewModel.onListIndexChanged($0) }
        )) {
            ForEach(viewModel.lists.indices, id: \.self) { index in
                ExternalUserLightweightListContentScrollView(
                    list: viewModel.lists[index],
                    places: viewModel.places(forListAt: index),
                    isLoading: viewModel.isLoading(forListAt: index),
                    onNavigateToPlace: { placeId in
                        navigationPath.append(placeId)
                    }
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }

    private var singleListScrollView: some View {
        ExternalUserLightweightListContentScrollView(
            list: viewModel.currentList,
            places: viewModel.currentPlaces,
            isLoading: viewModel.isLoadingPlaces,
            onNavigateToPlace: { placeId in
                navigationPath.append(placeId)
            }
        )
    }
}

// MARK: - External User Lightweight List Content Scroll View

/// Displays the scrollable content for an external user's list.
struct ExternalUserLightweightListContentScrollView: View {
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    let isLoading: Bool
    let onNavigateToPlace: ((String) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if isLoading && places.isEmpty {
            loadingView
        } else if !places.isEmpty {
            placesGrid
        } else {
            emptyState
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading places...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placesGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(places.enumerated()), id: \.element.id) { _, place in
                    PopupPlaceCard(
                        place: place,
                        preferTikTokThumbnail: true,
                        onNavigate: onNavigateToPlace
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No places in this list")
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.vertical, 30)
    }
}
