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
    @EnvironmentObject var userSession: UserSession
    
    var onMapTap: (() -> Void)? // Callback to notify when the map is tapped
    
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
        // Clear all existing markers before adding new ones
        uiView.clear()

        // 1) Loop through each placeListViewModel in the user session
        if let placeListVMs = userSession.profileViewModel?.placeListViewModels {
            for listVM in placeListVMs {
                // 2) Each list might have its own array of “places” with placeIDs
                //    Replace this with your real data structure:
                for place in listVM.placeList.places {
                    // For each placeID, call fetchPlace to get the actual GMSPlace
                    GMSPlacesClient.shared().fetchPlace(
                        fromPlaceID: place.placeID, // e.g. "ChIJN1t_tDeuEmsRUsoyG83frY4"
                        placeFields: [.coordinate, .name], // Request whatever fields you need
                        sessionToken: nil
                    ) { fetchedPlace, error in
                        if let error = error {
                            print("Error fetching place: \(error)")
                            return
                        }
                        guard let fetchedPlace = fetchedPlace else { return }
                        
                        // Create a marker at the fetched coordinate
                        let marker = GMSMarker(position: fetchedPlace.coordinate)
                        marker.title = fetchedPlace.name
                        marker.map = uiView
                    }
                }
            }
        }

        // 3) If a place is selected from search/autocomplete,
        //    move the camera & add a special marker for it
        if let place = selectedPlace {
            // Only animate if this is a new selection
            if context.coordinator.lastSelectedPlaceID != place.placeID {
                let camera = GMSCameraPosition.camera(
                    withLatitude: place.coordinate.latitude,
                    longitude: place.coordinate.longitude,
                    zoom: 15.0
                )
                uiView.animate(to: camera)
                
                // Marker for the selected place
                let marker = GMSMarker(position: place.coordinate)
                marker.title = place.name
                marker.map = uiView
                
                // Record that we’ve moved to this place
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
        var lastSelectedPlaceID: String?

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            if gesture {
                // If user manually pans the map, clear any search results & call onMapTap
                DispatchQueue.main.async {
                    self.parent.searchResults = []
                    self.parent.onMapTap?()
                }
            }
        }
    }
}
