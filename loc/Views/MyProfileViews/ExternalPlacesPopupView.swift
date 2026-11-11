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
    /// Supplies the profile's "Near me" results when the map was opened from the grid with Near me on.
    @ObservedObject var recentlyImportedVM: RecentlyImportedViewModel
    var showNearbyFilter: Bool = true
    var onViewOnMap: (() -> Void)? = nil

    /// Whether this sheet mirrors the profile's "Near me" toggle instead of the full import list.
    private var isNearMe: Bool { recentlyImportedVM.mapNearMeLocation != nil }

    var body: some View {
        PlaceListPopupView(
            title: isNearMe ? "Imported near me" : "Saved Videos",
            count: isNearMe ? recentlyImportedVM.nearbyPlaces.count : externalContentVM.totalExternalPlacesCount,
            isLoading: isNearMe
                ? recentlyImportedVM.isLoadingNearby && recentlyImportedVM.nearbyPlaces.isEmpty
                : externalContentVM.isLoadingExternalPlaces,
            isLoadingMore: isNearMe ? false : externalContentVM.isLoadingMoreExternalPlaces,
            places: isNearMe ? recentlyImportedVM.nearbyPlaces : externalContentVM.lightweightExternalPlaces,
            hasMore: isNearMe ? false : externalContentVM.hasMoreExternalPlaces,
            emptyIcon: "video",
            emptyTitle: isNearMe ? "Nothing imported nearby"
                : (externalContentVM.isNearbyFilterEnabled ? "No Nearby Videos" : "No Videos Yet"),
            emptyMessage: isNearMe ? "Places you import within 20 miles show up here"
                : (externalContentVM.isNearbyFilterEnabled
                    ? "No video places found in the current map area"
                    : "Places you add from shared videos will appear here"),
            loadMore: {
                guard !isNearMe else { return }
                await externalContentVM.loadMoreExternalPlaces()
            },
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
                if showNearbyFilter && !isNearMe {
                    nearbyFilterToggle
                }
            },
            onRemove: { place in
                profile.externalContentViewModel.deleteExternalPlace(place)
            },
            fitsMapToPlaces: isNearMe || !externalContentVM.isNearbyFilterEnabled
        )
        .onAppear {
            externalContentVM.currentMapRegion = appCoordinator.currentMapRegion
            if !isNearMe && externalContentVM.lightweightExternalPlaces.isEmpty {
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
