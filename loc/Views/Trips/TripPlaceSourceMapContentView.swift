//
//  TripPlaceSourceMapContentView.swift
//  loc
//
//  Map with annotations + scrollable draggable place list for the trip place picker
//

import SwiftUI
import MapKit

/// Displays a map with place annotations and a scrollable draggable place list below.
struct TripPlaceSourceMapContentView: View {
    @ObservedObject var mapVM: TripMapPlacePickerViewModel
    let alreadyAddedIds: Set<String>
    var onPlaceTap: ((String) -> Void)?

    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        if mapVM.isLoading {
            ProgressView("Loading places...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if mapVM.allPlaces.isEmpty {
            emptyState
        } else {
            mapAndListContent
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No saved places with locations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Map + List

    /// Splits available space 60/40 between map and place list using GeometryReader.
    private var mapAndListContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                mapSection
                    .frame(height: geometry.size.height * 0.6)
                Divider()
                placeListSection
                    .frame(height: geometry.size.height * 0.4)
            }
        }
    }

    /// Map displaying annotations at each saved place location.
    private var mapSection: some View {
        Map(position: $mapPosition) {
            ForEach(mapVM.mappablePlaces) { place in
                if let lat = place.latitude, let lng = place.longitude {
                    Annotation(
                        place.name,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    ) {
                        tripPlaceAnnotation(
                            name: place.name,
                            isAdded: alreadyAddedIds.contains(place.place_id)
                        )
                    }
                }
            }
        }
        .mapStyle(.standard)
    }

    /// Inline annotation view — plain view instead of Button to avoid rendering issues inside Map.
    private func tripPlaceAnnotation(name: String, isAdded: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: isAdded ? "checkmark.circle.fill" : "mappin.circle.fill")
                .font(.title2)
                .foregroundColor(isAdded ? .green : .accentColor)
                .background(
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                )

            Text(name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    /// Scrollable list of all places that can be dragged to the calendar.
    private var placeListSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(mapVM.allPlaces) { place in
                    TripDraggableMapPlaceRow(
                        place: place,
                        isAlreadyAdded: alreadyAddedIds.contains(place.place_id),
                        onTap: { onPlaceTap?(place.place_id) }
                    )
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
    }
}
