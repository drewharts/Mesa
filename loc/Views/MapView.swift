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
    @EnvironmentObject var placeTypeFilterVM: PlaceTypeFilterViewModel
    
    @Binding var recenterMap: Bool
    
    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State private var showCreatePlacePopup = false
    @State private var newPlaceName = ""
    @State private var newPlaceDescription = ""
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    @State private var mapPosition = MapCameraPosition.automatic
    @State private var mapRefreshToggle = false
    @State private var showVisiblePlacesPopup = false
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        
        ZStack {
            MapReader { mapProxy in
                Map(position: $mapPosition) {
                    ForEach(placeTypeFilterVM.getFilteredPlaces().compactMap { place -> PlaceAnnotationItem? in
                        guard let coordinate = place.coordinate else {
                            print("⚠️ [MapView] Place '\(place.name)' has no coordinate, skipping annotation")
                            return nil
                        }
                        return PlaceAnnotationItem(
                            id: place.id,
                            coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
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
                                print("Place ID: \(place.place.id.uuidString)")
                                selectedPlaceVM.selectedPlace = place.place
                            }
                        }
                    }
                    // Current location dot
                    if let userLocation = locationManager.currentLocation?.coordinate {
                        Annotation(
                            "",
                            coordinate: userLocation,
                            anchor: .center
                        ) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 18, height: 18)
                                )
                                .shadow(radius: 4)
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
                                // Convert the tap location to map coordinates using MapProxy
                                if let coordinate = mapProxy.convert(drag.location, from: .local) {
                                    newPlaceCoordinate = coordinate
                                    showCreatePlacePopup = true
                                }
                            default:
                                break
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            onMapTap?()
                        }
                )
            }
            .onChange(of: selectedPlaceVM.selectedPlace) { oldValue, newValue in
                guard newValue != nil else {
                    // Reset to default if no place is selected
                    withAnimation(.easeOut) {
                        mapPosition = .camera(MapCamera(centerCoordinate: defaultCenter, distance: 100))
                    }
                    return
                }
                // No zoom animation when selecting a place - just show the detail view
            }
            .onChange(of: recenterMap) { oldValue, newValue in
                if newValue {
                    let coords = locationManager.currentLocation?.coordinate ?? defaultCenter
                    withAnimation(.easeInOut) {
                        mapPosition = .camera(MapCamera(centerCoordinate: coords, distance: 1000))
                    }
                    recenterMap = false
                }
            }
            
            // Visible Places Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showVisiblePlacesPopup = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16, weight: .medium))
                            Text("Places")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.blue)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100) // Position above bottom UI elements
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
                
                // Calculate most frequent types
                placeTypeFilterVM.refreshMostFrequentTypes()
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
                        let generatedId = UUID().uuidString
                        selectedPlaceVM.allowAutoPresent = false
                        selectedPlaceVM.createNewPlace(idString: generatedId, name: name, description: description, coordinate: coordinate, userId: userId, profileVM: profile, detailPlaceVM: detailPlaceVM)
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
        .sheet(isPresented: $showVisiblePlacesPopup) {
            VisiblePlacesPopupView()
                .environmentObject(selectedPlaceVM)
                .environmentObject(placeTypeFilterVM)
                .presentationDragIndicator(.visible)
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
                await placeTypeFilterVM.refreshMostFrequentTypes()
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
