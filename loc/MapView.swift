//
//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import GoogleMaps
import GooglePlaces
import CoreLocation

struct MapView: UIViewRepresentable {
    @ObservedObject var locationManager = LocationManager()
    @Binding var searchResults: [GMSAutocompletePrediction]
    @Binding var selectedPlace: GMSPlace?
    let mapView = GMSMapView()

    func makeUIView(context: Context) -> GMSMapView {
        locationManager.requestLocationPermission()
        
        if let currentLocation = locationManager.currentLocation {
            let camera = GMSCameraPosition.camera(
                withLatitude: currentLocation.coordinate.latitude,
                longitude: currentLocation.coordinate.longitude,
                zoom: 10.0
            )
            mapView.camera = camera
        }
        
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        if let place = selectedPlace {
            let camera = GMSCameraPosition.camera(
                withLatitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude,
                zoom: 15.0
            )
            uiView.animate(to: camera)

            // Add a marker for the selected place
            let marker = GMSMarker(position: place.coordinate)
            marker.title = place.name
            marker.map = uiView
        } else if let updatedLocation = locationManager.currentLocation {
            let camera = GMSCameraPosition.camera(
                withLatitude: updatedLocation.coordinate.latitude,
                longitude: updatedLocation.coordinate.longitude,
                zoom: 10.0
            )
            uiView.animate(to: camera)
        }
    }
}

