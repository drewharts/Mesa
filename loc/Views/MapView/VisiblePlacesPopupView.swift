//
//  VisiblePlacesPopupView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//
//  Shows places currently visible on the map with Friends/Community filter toggle.
//  
//  Architecture:
//  - View owns ViewModel via @StateObject
//  - View acts as coordinator: extracts data from EnvironmentObjects and configures ViewModel
//  - ViewModel depends only on services (SRP), not other ViewModels
//  - Grid cells are dumb components with callbacks
//

import SwiftUI
import MapKit

struct VisiblePlacesPopupView: View {
    
    // MARK: - Input
    
    let mapRegion: MKCoordinateRegion?
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject private var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject private var mapViewModel: MapViewModel
    @EnvironmentObject private var profile: ProfileViewModel
    
    // MARK: - ViewModel (owned by this View)

    @StateObject private var viewModel = VisiblePlacesPopupViewModel()
    @State private var navigationPath = NavigationPath()

    // MARK: - Layout

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                headerSection
                filterPicker
                contentSection
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
                    .id(placeId)
            }
        }
        .onAppear {
            configureViewModel()
            sheetVM.beginSession(listId: "places_in_view", placeCount: 0, isExternal: false, source: "places_in_view")
        }
        .onDisappear { sheetVM.endSession() }
    }
    
    // MARK: - ViewModel Configuration
    
    /// Configures the ViewModel with the map's in-memory places and images, keeping it decoupled from other ViewModels.
    private func configureViewModel() {
        viewModel.configure(
            mapRegion: mapRegion,
            userId: profile.user?.id,
            seedAnnotations: mapViewModel.viewportAnnotations,
            seedCommunityMarkers: mapViewModel.communityMarkers,
            existingPlaceImages: detailPlaceViewModel.placeImages
        )
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
                HStack {
                    Spacer()
                    Text("Places in View")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Filter Picker
    
    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.selectedFilter) {
            ForEach(VisiblePlacesFilter.allCases) { filter in
                Label(filter.rawValue, systemImage: filter.icon)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Content Section

    @ObservedObject private var sheetVM = ListMapSheetViewModel.shared
    @ObservedObject private var placeMeta = ListPlaceMetaStore.shared

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.visiblePlaces.isEmpty && !viewModel.showsLoadingIndicator {
            emptyStateView
        } else {
            ListPlacesScrollView(
                places: viewModel.tilePlaces,
                isLoadingInitial: viewModel.showsLoadingIndicator,
                isLoadingMore: false,
                showAddedBy: false,
                focusedPlaceId: sheetVM.focusedPlaceId,
                scrollRequest: sheetVM.scrollRequest,
                locationText: { placeMeta.location(for: $0) },
                onRowAppear: { place in
                    placeMeta.requestNeighborhood(for: place)
                    if let index = viewModel.index(of: place.place_id) {
                        viewModel.onCellAppear(index: index)
                    }
                },
                onLoadMore: {},
                onSelect: { handlePlaceTap($0) },
                onOpenDetail: { handlePlaceTap($0) },
                onRemove: nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: viewModel.selectedFilter == .friends ? "person.2" : "globe")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No \(viewModel.selectedFilter.rawValue.lowercased()) places in view")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(emptyStateHint)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding(.vertical, 30)
    }
    
    private var emptyStateHint: String {
        switch viewModel.selectedFilter {
        case .friends:
            return "Try zooming out or panning to see more places from your network"
        case .community:
            return "Try zooming out to discover places saved by the community"
        }
    }
    
    // MARK: - Actions
    
    /// Tile tap: open the place in this sheet and center its pin, so the map is on it afterwards.
    private func handlePlaceTap(_ place: LightweightPlace) {
        sheetVM.focus(place: place, source: .row)
        sheetVM.ensureAtLeastHalf()
        var path = NavigationPath()
        path.append(place.place_id)
        navigationPath = path
    }
}
