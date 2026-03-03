//
//  FeedCardMapView.swift
//  loc
//
//  DUMB Component: Interactive map display with a single place marker.
//  Single Responsibility: Render a map centered on a coordinate that users can pan and zoom.
//

import SwiftUI
import MapKit

struct FeedCardMapView: View {
    let latitude: Double
    let longitude: Double
    let placeName: String

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var region: MapCameraPosition {
        .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    var body: some View {
        Map(initialPosition: region) {
            Marker(placeName, coordinate: coordinate)
                .tint(.red)
        }
    }
}
