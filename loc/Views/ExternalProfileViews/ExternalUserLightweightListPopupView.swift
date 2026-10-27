//
//  ExternalUserLightweightListPopupView.swift
//  loc
//
//  Displays external user's list popup when viewing from the map.
//  Uses ExternalListPopupViewModel for self-contained data loading.
//

import SwiftUI
import Combine

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

    /// Map-first coordination: sheet height, focused place, camera requests.
    @ObservedObject private var sheetVM = ListMapSheetViewModel.shared
    /// Category/neighborhood line data for rows.
    @ObservedObject private var placeMeta = ListPlaceMetaStore.shared

    @State private var navigationPath = NavigationPath()
    @State private var hasInitiallyAppeared = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                popupHeader
                popupContent
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
                    .id(placeId)
            }
        }
        .onReceive(presentationService.$pendingPlaceNavigation.compactMap { $0 }) { placeId in
            // When a map pin is tapped while the list sheet is open, highlight and scroll to its row.
            // Uses onReceive (Combine) instead of onChange for reliable delivery even when
            // a navigation destination is pushed on the stack.
            presentationService.pendingPlaceNavigation = nil
            handleMapPinTap(placeId)
        }
        .onAppear {
            // Clear navigation path only on the first appearance (when the sheet opens).
            guard !hasInitiallyAppeared else { return }
            hasInitiallyAppeared = true
            navigationPath = NavigationPath()
            sheetVM.beginSession(
                listId: viewModel.currentList.list_id,
                placeCount: viewModel.currentList.place_count,
                isExternal: true,
                source: "external_map_sheet"
            )
        }
        .onDisappear {
            sheetVM.endSession()
        }
        .task {
            await viewModel.loadPlacesIfNeeded()
            sheetVM.fitToPlaces(viewModel.currentPlaces)
            placeMeta.prefetchCities(for: viewModel.currentPlaces)
        }
    }

    // MARK: - Map-First Actions

    /// Row tap: highlight and center its pin. Tapping the already-selected row opens its details.
    private func handleRowTap(_ place: LightweightPlace) {
        if sheetVM.isFocused(place.place_id) {
            openPlaceDetail(place)
        } else {
            sheetVM.focus(place: place, source: .row)
        }
    }

    /// Opens the place page inside the sheet and selects the place on the map.
    private func openPlaceDetail(_ place: LightweightPlace) {
        sheetVM.ensureAtLeastHalf()
        navigationPath.append(place.place_id)
        Task {
            guard let fetched = try? await PlaceService.shared.fetchPlace(withId: place.place_id) else { return }
            selectedPlaceVM.selectPlaceAndFetchDetails(fetched, shouldAnimateMap: true)
        }
    }

    /// Pin tap: scroll to and highlight the row; a second tap on the same pin opens its details.
    /// While a place page is open, a pin tap swaps to that place (previous behavior).
    private func handleMapPinTap(_ placeId: String) {
        let tapped = viewModel.currentPlaces.first {
            $0.place_id.caseInsensitiveCompare(placeId) == .orderedSame
        }
        let isShowingDetail = !navigationPath.isEmpty
        guard let tapped else {
            replaceDetail(with: placeId)
            return
        }
        if isShowingDetail {
            sheetVM.focus(place: tapped, source: .pin)
            replaceDetail(with: tapped.place_id)
        } else if sheetVM.isFocused(tapped.place_id) {
            replaceDetail(with: tapped.place_id)
        } else {
            sheetVM.focus(place: tapped, source: .pin)
        }
    }

    /// Replaces the navigation stack with a single place page.
    private func replaceDetail(with placeId: String) {
        sheetVM.ensureAtLeastHalf()
        var newPath = NavigationPath()
        newPath.append(placeId)
        navigationPath = newPath
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
                    .foregroundColor(.primary)

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
            Image(systemName: "xmark")
                .font(.body)
                .foregroundColor(.gray)
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
                placesList(
                    places: viewModel.places(forListAt: index),
                    isLoading: viewModel.isLoading(forListAt: index),
                    showAddedBy: viewModel.lists[index].isCollaborative
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }

    private var singleListScrollView: some View {
        placesList(
            places: viewModel.currentPlaces,
            isLoading: viewModel.isLoadingPlaces,
            showAddedBy: viewModel.currentList.isCollaborative
        )
    }

    /// Place rows for one list, wired to the map-first view model.
    private func placesList(places: [LightweightPlace], isLoading: Bool, showAddedBy: Bool) -> some View {
        ListPlacesScrollView(
            places: places,
            isLoadingInitial: isLoading,
            isLoadingMore: false,
            showAddedBy: showAddedBy,
            focusedPlaceId: sheetVM.focusedPlaceId,
            scrollRequest: sheetVM.scrollRequest,
            locationText: { placeMeta.location(for: $0) },
            onRowAppear: { placeMeta.requestNeighborhood(for: $0) },
            onLoadMore: {},
            onSelect: { handleRowTap($0) },
            onOpenDetail: { openPlaceDetail($0) },
            onRemove: nil
        )
    }
}
