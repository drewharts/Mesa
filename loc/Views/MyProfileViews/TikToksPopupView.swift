//
//  TikToksPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated TikTok places in a popup grid
//  MVVM: Delegates data loading and state to ProfileTikTokViewModel
//  DUMB Component: Uses PlaceListPopupView for consistent popup behavior

import SwiftUI

struct TikToksPopupView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    @ObservedObject var tikTokVM: ProfileTikTokViewModel
    var showNearbyFilter: Bool = true
    var onViewOnMap: (() -> Void)? = nil

    var body: some View {
        PlaceListPopupView(
            title: "TikToks",
            count: tikTokVM.totalExternalPlacesCount,
            isLoading: tikTokVM.isLoadingTikTokPlaces,
            isLoadingMore: tikTokVM.isLoadingMoreExternalPlaces,
            places: tikTokVM.lightweightExternalPlaces,
            hasMore: tikTokVM.hasMoreExternalPlaces,
            emptyIcon: "video",
            emptyTitle: tikTokVM.isNearbyFilterEnabled ? "No Nearby TikToks" : "No TikToks Yet",
            emptyMessage: tikTokVM.isNearbyFilterEnabled
                ? "No TikTok places found in the current map area"
                : "Places you add from TikTok videos will appear here",
            loadMore: { await tikTokVM.loadMoreExternalPlaces() },
            onViewOnMap: onViewOnMap,
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: true,
                    onNavigate: navigate
                )
                .contextMenu {
                    Button(role: .destructive) {
                        profile.tikTokViewModel.deleteTikTokPlace(place)
                    } label: {
                        Label("Delete TikTok Place", systemImage: "trash")
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
            tikTokVM.currentMapRegion = appCoordinator.currentMapRegion
            if tikTokVM.lightweightExternalPlaces.isEmpty {
                profile.tikTokViewModel.refreshTikTokPlacesAfterImport()
            }
        }
        .onChange(of: appCoordinator.currentMapRegion?.center.latitude) { _, _ in
            guard let region = appCoordinator.currentMapRegion else { return }
            tikTokVM.reloadForRegionChange(newRegion: region)
        }
        .onChange(of: appCoordinator.currentMapRegion?.center.longitude) { _, _ in
            guard let region = appCoordinator.currentMapRegion else { return }
            tikTokVM.reloadForRegionChange(newRegion: region)
        }
        .onChange(of: appCoordinator.currentMapRegion?.span.latitudeDelta) { _, _ in
            guard let region = appCoordinator.currentMapRegion else { return }
            tikTokVM.reloadForRegionChange(newRegion: region)
        }
        .onChange(of: appCoordinator.currentMapRegion?.span.longitudeDelta) { _, _ in
            guard let region = appCoordinator.currentMapRegion else { return }
            tikTokVM.reloadForRegionChange(newRegion: region)
        }
    }

    // MARK: - Nearby Filter Toggle

    private var nearbyFilterToggle: some View {
        HStack(spacing: 8) {
            NearbyFilterButton(
                title: "Recent",
                isSelected: !tikTokVM.isNearbyFilterEnabled
            ) {
                guard tikTokVM.isNearbyFilterEnabled else { return }
                tikTokVM.currentMapRegion = appCoordinator.currentMapRegion
                tikTokVM.toggleNearbyFilter()
            }
            NearbyFilterButton(
                title: "Nearby",
                isSelected: tikTokVM.isNearbyFilterEnabled
            ) {
                guard !tikTokVM.isNearbyFilterEnabled else { return }
                tikTokVM.currentMapRegion = appCoordinator.currentMapRegion
                tikTokVM.toggleNearbyFilter()
            }
        }
    }
}
