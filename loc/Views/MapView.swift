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
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var profile: ProfileViewModel
    
    var onMapTap: (() -> Void)? // Callback to notify when the map is tapped
    
    let googlePlacesService = GooglePlacesService()
    let mapView = GMSMapView()
    
    func makeUIView(context: Context) -> GMSMapView {
        // Enable showing user's current location
        mapView.isMyLocationEnabled = true
        
        // Set the coordinator as the delegate for map interactions
        mapView.delegate = context.coordinator
        
        // Set a default camera position (global view to start)
        let defaultCamera = GMSCameraPosition.camera(
            withLatitude: 0,
            longitude: 0,
            zoom: 1.0
        )
        mapView.camera = defaultCamera

        // After a brief delay, center on user location if available (only once)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let currentLocation = locationManager.currentLocation,
               !context.coordinator.hasCenteredOnUser {
                
                let camera = GMSCameraPosition.camera(
                    withLatitude: currentLocation.coordinate.latitude,
                    longitude: currentLocation.coordinate.longitude,
                    zoom: 15.0
                )
                mapView.animate(to: camera)
                context.coordinator.hasCenteredOnUser = true
            }
        }

        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // Clear existing markers
        uiView.clear()
        
        // Loop through the cached places from profile view model
        for (_, places) in profile.placeListGMSPlaces {
            for place in places {
                let marker = GMSMarker(position: place.coordinate)
                marker.title = place.name
                marker.userData = place  // So that the marker delegate can use it
                marker.map = uiView
            }
        }
        // add user favorites as well to the map of pins
        for place in profile.userFavorites {
            let marker = GMSMarker(position: place.coordinate)
            marker.title = place.name
            marker.userData = place
            marker.map = uiView
        }
        
        // If a place is selected from search/autocomplete, move the camera & add a special marker for it
        if let selectedPlace = selectedPlaceVM.selectedPlace {
            if context.coordinator.lastSelectedPlaceID != selectedPlace.placeID {
                let camera = GMSCameraPosition.camera(
                    withLatitude: selectedPlace.coordinate.latitude,
                    longitude: selectedPlace.coordinate.longitude,
                    zoom: 15.0
                )
                uiView.animate(to: camera)
                
                // Marker for the selected place
                let marker = GMSMarker(position: selectedPlace.coordinate)
                marker.title = selectedPlace.name
                marker.map = uiView
                
                // Record that we’ve moved to this place
                context.coordinator.lastSelectedPlaceID = selectedPlace.placeID
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: MapView
        var hasCenteredOnUser = false
        var lastSelectedPlaceID: String?

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            if gesture {
                DispatchQueue.main.async {
                    self.parent.searchResults = []
                    self.parent.onMapTap?()
                }
            }
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            // Retrieve the GMSPlace from the marker's userData
            if let gmsPlace = marker.userData as? GMSPlace {
                // Update the selectedPlaceViewModel
                DispatchQueue.main.async {
                    self.parent.selectedPlaceVM.selectedPlace = gmsPlace
                    self.parent.selectedPlaceVM.isDetailSheetPresented = true
                }
            }
            // Return false to allow the default behavior (like showing info windows)
            return false
        }
    }
}
