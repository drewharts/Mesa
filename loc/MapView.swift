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
        if let updatedLocation = locationManager.currentLocation {
            let camera = GMSCameraPosition.camera(
                withLatitude: updatedLocation.coordinate.latitude,
                longitude: updatedLocation.coordinate.longitude,
                zoom: 10.0
            )
            uiView.animate(to: camera)
        }
    }

}
