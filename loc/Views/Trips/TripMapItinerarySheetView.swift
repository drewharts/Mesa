//
//  TripMapItinerarySheetView.swift
//  loc
//
//  Bottom sheet container for the trip map with day selector and place list
//

import SwiftUI

/// Bottom sheet showing day pills and itinerary list for the trip map.
struct TripMapItinerarySheetView: View {
    @ObservedObject var viewModel: TripMapViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TripMapDaySelectorView(viewModel: viewModel)
                Divider()
                TripMapDayPlacesListView(viewModel: viewModel)
            }
            .navigationTitle(viewModel.trip.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $viewModel.selectedPlaceIdForDetail) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
            }
        }
    }
}
