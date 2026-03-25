//  PhotoClusterMapView.swift
//  loc
//
//  DUMB Component: Non-interactive map showing pins for each photo cluster.
//  Single Responsibility: Render a MapKit map with color-coded cluster pins.

import SwiftUI
import MapKit

struct PhotoClusterMapView: View {
    let clusters: [PhotoLocationCluster]

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)
    private let pinColors: [Color] = [
        .red, .blue, .orange, .purple, .green, .pink, .cyan, .brown
    ]

    private var region: MapCameraPosition {
        guard !clusters.isEmpty else {
            return .automatic
        }

        let lats = clusters.map { $0.latitude }
        let lngs = clusters.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )

        let latSpan = max((lats.max()! - lats.min()!) * 1.5, 0.01)
        let lngSpan = max((lngs.max()! - lngs.min()!) * 1.5, 0.01)

        return .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lngSpan)
        ))
    }

    var body: some View {
        Map(initialPosition: region) {
            ForEach(Array(clusters.enumerated()), id: \.element.id) { offset, cluster in
                Marker(
                    cluster.addressHint,
                    coordinate: CLLocationCoordinate2D(
                        latitude: cluster.latitude,
                        longitude: cluster.longitude
                    )
                )
                .tint(pinColors[offset % pinColors.count])
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .allowsHitTesting(false)
        .padding(.horizontal, 20)
    }
}
