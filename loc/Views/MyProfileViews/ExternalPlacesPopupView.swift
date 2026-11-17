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
    /// Owns the sheet's All / Near me toggle and the nearby results.
    @ObservedObject var recentlyImportedVM: RecentlyImportedViewModel
    var showNearbyFilter: Bool = true
    var onViewOnMap: (() -> Void)? = nil

    /// Whether the sheet is showing Near me results instead of the full import list.
    private var isNearMe: Bool { recentlyImportedVM.isShowingNearby }

    var body: some View {
        PlaceListPopupView(
            title: isNearMe ? "Imported near me" : "Saved Videos",
            count: isNearMe ? recentlyImportedVM.nearbyPlaces.count : externalContentVM.totalExternalPlacesCount,
            isLoading: isNearMe
                ? recentlyImportedVM.isLoadingNearbyResults
                : externalContentVM.isLoadingExternalPlaces,
            isLoadingMore: isNearMe ? false : externalContentVM.isLoadingMoreExternalPlaces,
            places: isNearMe ? recentlyImportedVM.nearbyPlaces : externalContentVM.lightweightExternalPlaces,
            hasMore: isNearMe ? false : externalContentVM.hasMoreExternalPlaces,
            emptyIcon: "video",
            emptyTitle: isNearMe ? "Nothing imported nearby" : "No Videos Yet",
            emptyMessage: isNearMe
                ? "Places you import within 20 miles show up here"
                : "Places you add from shared videos will appear here",
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
                if showNearbyFilter {
                    RecentlyImportedScopeToggle(
                        selectedScope: recentlyImportedVM.scope,
                        isNearMeAvailable: recentlyImportedVM.isNearMeAvailable,
                        onSelect: { recentlyImportedVM.selectScope($0) }
                    )
                }
            },
            onRemove: { place in
                profile.externalContentViewModel.deleteExternalPlace(place)
            },
            fitsMapToPlaces: true,
            framingRegion: recentlyImportedVM.mapFramingRegion,
            framingKey: recentlyImportedVM.scope.rawValue
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
}
