//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    
    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showCreatePlacePopup = false
    @State private var newPlaceName = ""
    @State private var newPlaceDescription = ""
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        let places = detailPlaceVM.getAllSavedDetailPlaces().compactMap { place -> PlaceAnnotationItem? in
            guard let geoPoint = place.coordinate else { return nil }
            return PlaceAnnotationItem(
                id: place.id,
                coordinate: CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude),
                place: place
            )
        }
        let initCamera = MapCamera(centerCoordinate: currentCoords, distance: 1000)
        let initialPosition = MapCameraPosition.camera(initCamera)
        
        Map(initialPosition: initialPosition) {

        }
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
        .onTapGesture {
            // Handle map tap
            if let onTap = onMapTap {
                onTap()
            }
        }
        .onChange(of: selectedPlaceVM.selectedPlace) { newPlace in
            guard let place = newPlace, let geoPoint = place.coordinate else { return }
            let newCenter = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
            // Update camera when a place is selected
            withAnimation {
                // You may need to update this with the correct camera position API
            }
        }
    }
}

struct PlaceAnnotationItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let place: DetailPlace
}
