//  PlaceSelectionMiniMap.swift
//  loc
//
//  DUMB Component: Non-interactive mini-map showing the photo's GPS location.
//  Single Responsibility: Render a small MapKit map centered on a coordinate.

import SwiftUI
import MapKit

struct PlaceSelectionMiniMap: View {
    let latitude: Double
    let longitude: Double

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var region: MapCameraPosition {
        .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        Map(initialPosition: region) {
            Marker("Photo Location", coordinate: coordinate)
                .tint(mesaCharcoal)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .allowsHitTesting(false)
        .padding(.horizontal, 20)
    }
}
