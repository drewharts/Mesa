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
        let places = detailPlaceVM.getAllSavedDetailPlaces().compactMap { place -> PlaceAnnotationItem? in
            guard let geoPoint = place.coordinate else { return nil }
            return PlaceAnnotationItem(
                id: place.id,
                coordinate: CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude),
                place: place
            )
        }
        
        Map(position: $mapPosition) {
            ForEach(places) { place in
                Annotation(
                    place.place.name,
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
        .onTapGesture {
            // Handle map tap
            if let onTap = onMapTap {
                onTap()
            }
        }
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
            await detailPlaceVM.refreshPlaces()
            
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
                await detailPlaceVM.refreshPlaces()
                detailPlaceVM.calculateAnnotationPlaces()
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
        VStack(spacing: 0) {
            if let annotationImage = annotationImage {
                Image(uiImage: annotationImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            } else if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            } else {
                Image(systemName: "mappin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.red)
                    .padding(5)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            
            Image(systemName: "triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundColor(.white)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
        .shadow(radius: 2)
    }
}
