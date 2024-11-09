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
    var onMapTap: (() -> Void)? // Callback to notify when the map is tapped

    let mapView = GMSMapView()

    func makeUIView(context: Context) -> GMSMapView {
        mapView.isMyLocationEnabled = true
        mapView.delegate = context.coordinator // Set the coordinator as the delegate

        // Set a default camera position first (e.g., a global view)
        let defaultCamera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 1.0)
        mapView.camera = defaultCamera

        // Delay briefly, then animate to user's current location if available
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let currentLocation = locationManager.currentLocation, !context.coordinator.hasCenteredOnUser {
                let camera = GMSCameraPosition.camera(withLatitude: currentLocation.coordinate.latitude,
                                                      longitude: currentLocation.coordinate.longitude,
                                                      zoom: 15.0)
                mapView.animate(to: camera)
                context.coordinator.hasCenteredOnUser = true
            }
        }

        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // If a place is selected and we haven't moved to it yet, move the camera
        if let place = selectedPlace {
            if context.coordinator.lastSelectedPlaceID != place.placeID {
                let camera = GMSCameraPosition.camera(withLatitude: place.coordinate.latitude,
                                                      longitude: place.coordinate.longitude,
                                                      zoom: 15.0)
                uiView.animate(to: camera)
                
                // Add a marker for the selected place
                uiView.clear()
                let marker = GMSMarker(position: place.coordinate)
                marker.title = place.name
                marker.map = uiView
                
                // Update the last selected place ID
                context.coordinator.lastSelectedPlaceID = place.placeID
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: MapView
        var hasCenteredOnUser = false
        var lastSelectedPlaceID: String? // Track the last selected place ID

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            if gesture {
                // Clear search results when the user moves the map
                DispatchQueue.main.async {
                    self.parent.searchResults = []
                    self.parent.onMapTap?()
                }
            }
        }
    }
}
