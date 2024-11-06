//
//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import GoogleMaps
import GooglePlaces

struct MapView: UIViewRepresentable {
    @Binding var searchResults: [GMSAutocompletePrediction]
    @Binding var selectedPlace: GMSPlace?
    @ObservedObject var locationManager: LocationManager
    @State private var hasCenteredOnUser = false

    let mapView = GMSMapView()

    func makeUIView(context: Context) -> GMSMapView {
        mapView.isMyLocationEnabled = true

        // Set a default camera position first (e.g., a global view)
        let defaultCamera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 1.0)
        mapView.camera = defaultCamera

        // Delay briefly, then animate to user's current location if available
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let currentLocation = locationManager.currentLocation, !hasCenteredOnUser {
                let camera = GMSCameraPosition.camera(withLatitude: currentLocation.coordinate.latitude,
                                                      longitude: currentLocation.coordinate.longitude,
                                                      zoom: 15.0)
                mapView.animate(to: camera) // Animate to the location
                hasCenteredOnUser = true // Mark as centered
            }
        }

        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // If a place is selected, move the camera to the selected place
        if let place = selectedPlace {
            let camera = GMSCameraPosition.camera(withLatitude: place.coordinate.latitude,
                                                  longitude: place.coordinate.longitude,
                                                  zoom: 15.0)
            uiView.animate(to: camera)
            
            // Add a marker for the selected place
            uiView.clear() // Clear previous markers
            let marker = GMSMarker(position: place.coordinate)
            marker.title = place.name
            marker.map = uiView
        }
    }
}
