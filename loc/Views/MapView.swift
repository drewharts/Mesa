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
        mapView.delegate = context.coordinator // Set the coordinator as the delegate

        // Set a default camera position first (e.g., a global view)
        let defaultCamera = GMSCameraPosition.camera(withLatitude: 0, longitude: 0, zoom: 1.0)
        mapView.camera = defaultCamera

        // Delay briefly, then animate to user's current location if available
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let currentLocation = locationManager.currentLocation, !hasCenteredOnUser {
                let camera = GMSCameraPosition.camera(withLatitude: currentLocation.coordinate.latitude,
                                                      longitude: currentLocation.coordinate.longitude,
                                                      zoom: 15.0)
                mapView.animate(to: camera)
                hasCenteredOnUser = true
            }
        }
        
        // Add tap gesture recognizer to dismiss keyboard and clear search results
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.mapTapped))
        mapView.addGestureRecognizer(tapGesture)

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
            uiView.clear()
            let marker = GMSMarker(position: place.coordinate)
            marker.title = place.name
            marker.map = uiView
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            // Clear selected place and search results if the camera position changes due to user interaction
            DispatchQueue.main.async {
                self.parent.selectedPlace = nil
                self.parent.searchResults = [] // Clear search results when the user moves the map
            }
        }

        @objc func mapTapped() {
            parent.searchResults = []
        }
    }
}

