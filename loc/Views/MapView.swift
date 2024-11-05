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
    @ObservedObject var locationManager: LocationManager // Observe the location manager

    let mapView = GMSMapView()

    func makeUIView(context: Context) -> GMSMapView {
        mapView.isMyLocationEnabled = true

        // Set the camera to the current location when the view is created
        if let currentLocation = locationManager.currentLocation {
            let camera = GMSCameraPosition.camera(withLatitude: currentLocation.coordinate.latitude,
                                                  longitude: currentLocation.coordinate.longitude,
                                                  zoom: 15.0)
            mapView.camera = camera
        }

        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // Update camera position if the current location changes
        if let currentLocation = locationManager.currentLocation {
            let camera = GMSCameraPosition.camera(withLatitude: currentLocation.coordinate.latitude,
                                                  longitude: currentLocation.coordinate.longitude,
                                                  zoom: 15.0)
            uiView.animate(to: camera)
        }

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
