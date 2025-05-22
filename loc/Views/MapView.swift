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
    @State private var mapRefreshToggle = false
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        
        ZStack {
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
            .gesture(
                LongPressGesture(minimumDuration: 0.7)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        switch value {
                        case .second(true, let drag?):
                            // Use the drag location to get the coordinate
                            if let window = UIApplication.shared.windows.first {
                                let location = drag.location
                                // Use MapProxy if available (iOS 17+), otherwise fallback to center
                                if #available(iOS 17.0, *) {
                                    // Use MapProxy to convert point to coordinate
                                    // This requires .mapOverlay, so we use a workaround here
                                    // For now, fallback to center
                                    newPlaceCoordinate = region.center
                                } else {
                                    newPlaceCoordinate = region.center
                                }
                            }
                            showCreatePlacePopup = true
                        default:
                            break
                        }
                    }
            )
            .onChange(of: selectedPlaceVM.selectedPlace) { oldValue, newValue in
                guard let place = newValue, let geoPoint = place.coordinate else {
                    // Reset to default if no place is selected
                    withAnimation(.easeOut) {
                        mapPosition = .camera(MapCamera(centerCoordinate: defaultCenter, distance: 100))
                    }
                    return
                }
                let newCenter = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
                withAnimation(.easeInOut) {
                    mapPosition = .camera(MapCamera(centerCoordinate: newCenter, distance: 500))
                }
            }
            .onAppear {
                // Set initial position when the view appears
                if let place = selectedPlaceVM.selectedPlace, let geoPoint = place.coordinate {
                    let newCenter = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
                    let camera = MapCamera(centerCoordinate: newCenter, distance: 500)
                    mapPosition = .camera(camera)
                } else {
                    let camera = MapCamera(centerCoordinate: currentCoords, distance: 1000)
                    mapPosition = .camera(camera)
                }
                
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
            
            // Show the create place popup if needed
            if showCreatePlacePopup, let coordinate = newPlaceCoordinate {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { showCreatePlacePopup = false }
                CreatePlacePopupView(
                    isPresented: $showCreatePlacePopup,
                    placeName: $newPlaceName,
                    placeDescription: $newPlaceDescription,
                    coordinate: coordinate
                ) { name, description in
                    if let userId = profile.user?.id {
                        selectedPlaceVM.createNewPlace(name: name, description: description, coordinate: coordinate, userId: userId)
                        // Reset fields
                        newPlaceName = ""
                        newPlaceDescription = ""
                        newPlaceCoordinate = nil
                    }
                }
                .frame(maxWidth: 400)
                .zIndex(2)
            }
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
