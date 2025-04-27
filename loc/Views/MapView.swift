//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import MapboxMaps
import FirebaseFirestore

struct MapView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var profile: ProfileViewModel
    
    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State var viewport: Viewport = .camera(center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0), zoom: 10)
    @State private var hasInitialized = false
    @State private var showCreatePlacePopup = false
    @State private var newPlaceName = ""
    @State private var newPlaceDescription = ""
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        
        if profile.isLoading || profile.profilePhoto == nil {
            ProgressView("Loading places…")
        } else {
            ZStack {
                Map(viewport: $viewport) {
                    Puck2D()
                    Puck2D(bearing: .heading)
                    
                    ForEvery(profile.getAllDetailPlaces()) { place in
                        let placeId = place.id.uuidString
                        if let annotationImage = profile.placeAnnotationImages[placeId] {
                            PointAnnotation(coordinate: CLLocationCoordinate2D(
                                latitude: place.coordinate!.latitude, longitude: place.coordinate!.longitude
                            ))
                            .image(.init(image: annotationImage, name: "dest-pin-\(placeId)"))
                            .onTapGesture {
                                selectedPlaceVM.selectedPlace = place
                                selectedPlaceVM.isDetailSheetPresented = true
                            }
                        }
                    }
                    
                    if let selectedPlace = selectedPlaceVM.selectedPlace {
                        let currentPlaceLocation = CLLocationCoordinate2D(
                            latitude: selectedPlace.coordinate!.latitude,
                            longitude: selectedPlace.coordinate!.longitude
                        )
                    }
                }
                .onMapTapGesture { _ in
                    onMapTap?()
                }
                .onMapLongPressGesture { context in
                    newPlaceCoordinate = context.coordinate
                    showCreatePlacePopup = true
                }
                .onAppear {
                    if !hasInitialized {
                        print("Initial setup with coords: \(currentCoords)")
                        viewport = .camera(center: currentCoords, zoom: 13)
                        hasInitialized = true
                    }
                    
                    // Add notification observer for map refresh
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshMapAnnotations"), object: nil, queue: .main) { [self] _ in
                        print("Received map refresh notification - refreshing annotations")
                        // Force map to redraw by making a minor state change
                        let currentCenter = viewport.camera?.center
                        // Create a very slightly different viewport to force refresh
                        withAnimation(.easeInOut(duration: 0.1)) {
                            viewport = .camera(center: currentCenter, zoom: viewport.camera?.zoom, bearing: viewport.camera?.bearing)
                        }
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
                .onChange(of: profile.placeAnnotationImages) { _ in
                    print("Place annotation images changed - refreshing map")
                    let currentViewport = viewport
                    viewport = currentViewport
                }
                .onDisappear {
                    // Remove notification observer
                    NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshMapAnnotations"), object: nil)
                }
                
                if showCreatePlacePopup, let coordinate = newPlaceCoordinate {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showCreatePlacePopup = false
                        }
                    
                    CreatePlacePopupView(
                        isPresented: $showCreatePlacePopup,
                        placeName: $newPlaceName,
                        placeDescription: $newPlaceDescription,
                        coordinate: coordinate
                    ) { name, description in
                        selectedPlaceVM.createNewPlace(
                            name: name,
                            description: description,
                            coordinate: coordinate,
                            userId: profile.userId
                        )
                    }
                    .padding()
                }
            }
        }
    }
}
