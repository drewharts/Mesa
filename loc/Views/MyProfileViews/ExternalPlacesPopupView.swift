//
//  ExternalPlacesPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated external places in a popup grid
//  MVVM: Delegates data loading and state to ProfileExternalContentViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior

import SwiftUI

struct ExternalPlacesPopupView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    @ObservedObject var externalContentVM: ProfileExternalContentViewModel
    var showNearbyFilter: Bool = true
    var onViewOnMap: (() -> Void)? = nil

    var body: some View {
        PlaceListPopupView(
            title: "Saved Videos",
            count: externalContentVM.totalExternalPlacesCount,
            isLoading: externalContentVM.isLoadingExternalPlaces,
            isLoadingMore: externalContentVM.isLoadingMoreExternalPlaces,
            places: externalContentVM.lightweightExternalPlaces,
            hasMore: externalContentVM.hasMoreExternalPlaces,
            emptyIcon: "video",
            emptyTitle: externalContentVM.isNearbyFilterEnabled ? "No Nearby Videos" : "No Videos Yet",
            emptyMessage: externalContentVM.isNearbyFilterEnabled
                ? "No video places found in the current map area"
                : "Places you add from shared videos will appear here",
            loadMore: { await externalContentVM.loadMoreExternalPlaces() },
            onViewOnMap: onViewOnMap,
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferExternalThumbnail: true,
                    onNavigate: navigate
                )
                .contextMenu {
                    Button(role: .destructive) {
                        profile.externalContentViewModel.deleteExternalPlace(place)
                    } label: {
                        Label("Delete Video Place", systemImage: "trash")
                    }
                }
            },
            headerAccessory: {
                if showNearbyFilter {
                    nearbyFilterToggle
                }
            }
        )
        .onAppear {
            externalContentVM.currentMapRegion = appCoordinator.currentMapRegion
            if externalContentVM.lightweightExternalPlaces.isEmpty {
                profile.externalContentViewModel.refreshExternalPlacesAfterImport()
            }
        }
        .onChange(of: appCoordinator.currentMapRegion?.center.latitude) { _, _ in
            guard let region = appCoordinator.currentMapRegion else { return }
            externalContentVM.reloadForRegionChange(newRegion: region)
        }
        .onChange(of: appCoordinator.currentMapRegion?.center.longitude) { _, _ in
            guard let region = appCoordinator.currentMapRegion else { return }
            externalContentVM.reloadForRegionChange(newRegion: region)
        }
        .onChange(of: appCoordinator.currentMapRegion?.span.latitudeDelta) { _, _ in
            guard let region = appCoordinator.currentMapRegion else { return }
            externalContentVM.reloadForRegionChange(newRegion: region)
        }
        .onChange(of: appCoordinator.currentMapRegion?.span.longitudeDelta) { _, _ in
            guard let region = appCoordinator.currentMapRegion else { return }
            externalContentVM.reloadForRegionChange(newRegion: region)
        }
    }

    // MARK: - Nearby Filter Toggle

    private var nearbyFilterToggle: some View {
        HStack(spacing: 8) {
            NearbyFilterButton(
                title: "Recent",
                isSelected: !externalContentVM.isNearbyFilterEnabled
            ) {
                guard externalContentVM.isNearbyFilterEnabled else { return }
                externalContentVM.currentMapRegion = appCoordinator.currentMapRegion
                externalContentVM.toggleNearbyFilter()
            }
            NearbyFilterButton(
                title: "Nearby",
                isSelected: externalContentVM.isNearbyFilterEnabled
            ) {
                guard !externalContentVM.isNearbyFilterEnabled else { return }
                externalContentVM.currentMapRegion = appCoordinator.currentMapRegion
                externalContentVM.toggleNearbyFilter()
            }
        }
    }
}
