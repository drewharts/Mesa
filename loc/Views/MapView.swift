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
    @EnvironmentObject var mapViewModel: MapViewModel

    @Binding var recenterMap: Bool
    var isSearchBarMinimized: Bool = true
    @Binding var isCreatePlacePopupActive: Bool

    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State private var showCreatePlacePopup = false
    @State private var newPlaceName = ""
    @State private var newPlaceDescription = ""
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    @State private var mapPosition = MapCameraPosition.automatic
    @State private var mapRefreshToggle = false
    @State private var showVisiblePlacesPopup = false
    @State private var currentMapRegion: MKCoordinateRegion?
    @State private var hasLoadedInitialViewport = false
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        
        ZStack {
            MapReader { mapProxy in
                Map(position: $mapPosition) {
                    ForEach(placeTypeFilterVM.filteredPlaces.compactMap { place -> PlaceAnnotationItem? in
                        guard let coordinate = place.coordinate else {
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
                                // Set selected place first (instant, shows cached data)
                                selectedPlaceVM.selectedPlace = place.place
                                // Show sheet immediately for instant feedback
                                selectedPlaceVM.isDetailSheetPresented = true
                                // Background data fetching and loading happens automatically via didSet
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
                .onMapCameraChange { context in
                    currentMapRegion = context.region
                    
                    // 🔄 CRITICAL: Dynamic loading on every viewport change
                    // This fires when user pans or zooms the map
                    mapViewModel.onMapRegionChange(context.region)
                }
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
            .onChange(of: showCreatePlacePopup) { oldValue, newValue in
                isCreatePlacePopupActive = newValue
            }
            
            // Visible Places Button - only show when search is minimized
            if isSearchBarMinimized {
                VStack {
                    HStack {
                        Button(action: {
                            showVisiblePlacesPopup = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "map")
                                    .font(.system(size: 14, weight: .medium))
                                Text("View")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            .shadow(radius: 4)
                        }
                        .padding(.leading, 20)
                        .padding(.top, 70) // Position below top safe area
                        Spacer()
                    }
                    Spacer()
                }
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
        .onAppear {
            // Set initial position when the view appears
            if let place = selectedPlaceVM.selectedPlace, let geoPoint = place.coordinate {
                let newCenter = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
                let camera = MapCamera(centerCoordinate: newCenter, distance: 500)
                mapPosition = .camera(camera)
            } else {
                // Default to current location or center of US
                let coords = locationManager.currentLocation?.coordinate ?? defaultCenter
                mapPosition = .camera(MapCamera(centerCoordinate: coords, distance: 10000))
            }

            // Setup notification observers
            setupNotificationObservers()
            
            // 🚀 Load initial viewport places
            if !hasLoadedInitialViewport, let region = currentMapRegion {
                Task {
                    await mapViewModel.loadInitialViewportPlaces(region)
                    hasLoadedInitialViewport = true
                }
            }
        }
         .onDisappear {
             // Remove notification observers
             removeNotificationObservers()
         }
        .task {
            // 🚀 CRITICAL: Load viewport places FIRST (instant map rendering)
            if !hasLoadedInitialViewport {
                // Minimal delay - just enough for map to initialize
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Always create a region - don't wait for currentMapRegion
                let coords = locationManager.currentLocation?.coordinate ?? defaultCenter
                let region = MKCoordinateRegion(
                    center: coords,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)  // Smaller initial viewport
                )
                
                await mapViewModel.loadInitialViewportPlaces(region)
                hasLoadedInitialViewport = true
                print("✅ [MapView] Initial viewport loaded instantly")
            }
            
            // Move expensive operations to background (non-blocking)
            Task.detached(priority: .background) {
                // Skip these expensive operations - they'll happen naturally as data loads
                // await profile.refreshUserPlaces()  // Not needed - viewport handles this
                // await detailPlaceVM.calculateAnnotationPlaces()  // Too expensive
                await placeTypeFilterVM.refreshMostFrequentTypes()  // Lightweight, keep it
            }
        }
        .sheet(isPresented: $showVisiblePlacesPopup) {
            VisiblePlacesPopupView(mapRegion: currentMapRegion)
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
