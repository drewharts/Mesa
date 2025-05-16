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
    @State private var mapPosition = MapCameraPosition.automatic
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        
        Map(position: $mapPosition) {
            ForEach(detailPlaceVM.savedDetailPlaces.compactMap { place -> PlaceAnnotationItem? in
                return PlaceAnnotationItem(
                    id: place.id,
                    coordinate: CLLocationCoordinate2D(latitude: place.coordinate!.latitude, longitude: place.coordinate!.longitude),
                    place: place
                )
            }) { place in
                Annotation(
                    "",
                    coordinate: place.coordinate,
                    anchor: .bottom
                ) {
                    PlaceAnnotationView(
                        place: place.place,
                        image: detailPlaceVM.placeAnnotations[place.place.id.uuidString],
                        annotationImage: detailPlaceVM.placeAnnotations[place.place.id.uuidString]
                    )
                    .onTapGesture {
                        selectedPlaceVM.selectedPlace = place.place
                    }
                }
            }
        }
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
        .onChange(of: selectedPlaceVM.selectedPlace) { oldValue, newValue in
            guard let place = newValue, let geoPoint = place.coordinate else { return }
            let newCenter = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
            // Update camera when a place is selected
            withAnimation {
                mapPosition = .camera(MapCamera(centerCoordinate: newCenter, distance: 500))
            }
        }
        .onAppear {
            // Set initial position when the view appears
            let camera = MapCamera(centerCoordinate: currentCoords, distance: 1000)
            mapPosition = .camera(camera)
            
            
            
            // Setup notification observer for place updates
            setupNotificationObservers()
        }
         .onDisappear {
             // Remove notification observers
             removeNotificationObservers()
         }
        .task {
            // Refresh places whenever the view appears
            await profile.refreshUserPlaces()
            
            // Calculate annotation images
            detailPlaceVM.calculateAnnotationPlaces()
        }
    }
    
    // MARK: - Private Methods
    
    // Listen for notifications about place changes
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshMapAnnotations"),
            object: nil,
            queue: .main
        ) { _ in
            // Refresh places when notified
            Task {
                await profile.refreshUserPlaces()
                await detailPlaceVM.calculateAnnotationPlaces()
            }
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("RefreshMapAnnotations"),
            object: nil
        )
    }
}

struct PlaceAnnotationItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let place: DetailPlace
}

struct PlaceAnnotationView: View {
    let place: DetailPlace
    let image: UIImage?
    let annotationImage: UIImage?
    
    var body: some View {
        VStack(spacing: 2) {
            if let annotationImage = annotationImage {
                Image(uiImage: annotationImage)
            }
        }
    }
}
