//
//  TripMapView.swift
//  loc
//
//  Full-screen map showing trip places colored by day with itinerary sheet
//

import SwiftUI
import MapKit

/// Full-screen trip map with day-colored pins and a persistent itinerary sheet.
struct TripMapView: View {
    @StateObject private var viewModel: TripMapViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showSheet = true

    init(trip: Trip, dayPlaces: [Int: [TripDayPlace]], dayIndices: [Int]) {
        _viewModel = StateObject(wrappedValue: TripMapViewModel(
            trip: trip,
            dayPlaces: dayPlaces,
            dayIndices: dayIndices
        ))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            mapContent
            closeButton
        }
        .sheet(isPresented: $showSheet) {
            TripMapItinerarySheetView(viewModel: viewModel)
                .presentationDetents([.height(180), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            viewModel.fitMapToAnnotations()
            viewModel.loadRoutes()
        }
    }

    /// The map with annotated pins.
    private var mapContent: some View {
        Map(position: $viewModel.mapPosition) {
            // Route lines between consecutive stops (drawn beneath the pins)
            ForEach(viewModel.routeSegments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(
                        segment.isCompleted
                            ? Color.gray.opacity(0.35)
                            : Color.mesaAccent.opacity(segment.isWalkingRoute ? 0.8 : 0.45),
                        style: StrokeStyle(lineWidth: segment.isWalkingRoute ? 4 : 2.5, lineCap: .round, lineJoin: .round)
                    )
            }

            ForEach(viewModel.annotations) { annotation in
                Annotation(
                    "",
                    coordinate: annotation.coordinate,
                    anchor: .center
                ) {
                    TripItineraryPinView(
                        annotation: annotation,
                        isSelected: viewModel.selectedAnnotationId == annotation.id,
                        onTap: { viewModel.selectAnnotation(annotation.id) }
                    )
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
    }

    /// Close button overlay in the top-left corner.
    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.primary, .ultraThinMaterial)
        }
        .padding(.top, 54)
        .padding(.leading, 16)
    }
}
