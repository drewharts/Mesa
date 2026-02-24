//
//  TripMapPlacePickerView.swift
//  loc
//
//  Map view showing all user's saved places for adding to trip
//

import SwiftUI
import MapKit

/// Map with place annotations for the trip place picker.
struct TripMapPlacePickerView: View {
    @ObservedObject var viewModel: TripMapPlacePickerViewModel
    let onAddPlace: (String) -> Void

    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        if viewModel.isLoading {
            ProgressView("Loading places...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.mappablePlaces.isEmpty {
            emptyState
        } else {
            mapContent
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No places with locations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Map Content

    private var mapContent: some View {
        Map(position: $mapPosition) {
            ForEach(viewModel.mappablePlaces) { place in
                if let lat = place.latitude, let lng = place.longitude {
                    Annotation(
                        place.name,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    ) {
                        TripMapPlacePin(
                            placeName: place.name,
                            isAlreadyAdded: viewModel.alreadyAddedPlaceIds.contains(place.place_id),
                            onTap: { onAddPlace(place.place_id) }
                        )
                    }
                }
            }
        }
        .mapStyle(.standard)
    }
}
