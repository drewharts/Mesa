//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import MapboxMaps

struct MapView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var profile: ProfileViewModel
    
    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State var viewport: Viewport = .camera(center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0), zoom: 10)
    @State private var hasInitialized = false
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        
        if profile.isLoading {
            ProgressView("Loading places…")
        } else {
            Map(viewport: $viewport) {
                Puck2D()
                Puck2D(bearing: .heading)
                
                ForEvery(profile.getAllDetailPlaces()) { place in
                    let placeId = place.id.uuidString
                    PointAnnotation(coordinate: CLLocationCoordinate2D(
                        latitude: place.coordinate!.latitude, longitude: place.coordinate!.longitude
                    ))
                    .image(.init(image: profile.placeAnnotationImages[placeId] ?? UIImage(named: "DestPin")!, name: "dest-pin-\(placeId)"))
                    .onTapGesture {
                        selectedPlaceVM.selectedPlace = place
                        selectedPlaceVM.isDetailSheetPresented = true
                    }
                }
                
                if let selectedPlace = selectedPlaceVM.selectedPlace {
                    let currentPlaceLocation = CLLocationCoordinate2D(
                        latitude: selectedPlace.coordinate!.latitude,
                        longitude: selectedPlace.coordinate!.longitude
                    )
                }
            }
            .onTapGesture {
                self.onMapTap?()
            }
            .onAppear {
                if !hasInitialized {
                    print("Initial setup with coords: \(currentCoords)")
                    viewport = .camera(center: currentCoords, zoom: 13)
                    hasInitialized = true
                }
            }
            .onChange(of: selectedPlaceVM.selectedPlace) { newPlace in
                guard let place = newPlace, let coordinate = place.coordinate else {
                    print("No valid place or coordinate")
                    return
                }
                let newCenter = CLLocationCoordinate2D(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                print("Updating camera to: \(newCenter)")
                withViewportAnimation(.easeOut(duration: 2.0)) {
                    viewport = .camera(center: newCenter, zoom: 14)
                }
            }
        }
    }
}
