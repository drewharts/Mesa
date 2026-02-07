//
//  MyPlacesListView.swift
//  loc
//
//  Shows user's created places in a popup list format.
//

import SwiftUI

struct MyPlacesListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @ObservedObject var myPlacesVM: ProfileMyPlacesViewModel

    var body: some View {
        PlaceListPopupView(
            title: "My Places",
            count: myPlacesVM.totalMyPlacesCount,
            isLoading: myPlacesVM.isMyPlacesLoading,
            isLoadingMore: myPlacesVM.isLoadingMoreMyPlaces,
            places: myPlacesVM.lightweightMyPlaces,
            hasMore: myPlacesVM.hasMoreMyPlaces,
            emptyIcon: "mappin.and.ellipse",
            emptyTitle: "No Places Created Yet",
            emptyMessage: "Press and hold on the map to create a place at any location",
            loadMore: { await myPlacesVM.loadMoreMyPlaces() },
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferTikTokThumbnail: true,
                    onNavigate: navigate
                )
                .contextMenu {
                    Button(role: .destructive) {
                        profile.deleteMyPlace(place)
                    } label: {
                        Label("Delete Place", systemImage: "trash")
                    }
                }
            }
        )
        .onAppear {
            if myPlacesVM.lightweightMyPlaces.isEmpty {
                Task { await myPlacesVM.loadInitialMyPlaces() }
            }
        }
    }
}

// MARK: - Helper Structs (Used by other views)
