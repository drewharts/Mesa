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
    @Binding var mapPosition: MapCameraPosition
    var isSearchBarMinimized: Bool = true
    @Binding var isCreatePlacePopupActive: Bool

    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State private var showCreatePlacePopup = false
    @State private var newPlaceName = ""
    @State private var newPlaceDescription = ""
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    @State private var mapRefreshToggle = false
    @State private var showVisiblePlacesPopup = false
    @State private var currentMapRegion: MKCoordinateRegion?
    @State private var hasLoadedInitialViewport = false
    
    var onMapTap: (() -> Void)?
    
    // Helper computed property to simplify type checking
    private var annotationsToDisplay: [PlaceAnnotation] {
        return mapViewModel.viewportAnnotations
    }
    
    // Map content extracted to help Swift type checker
    private var mapContentView: some View {
        Map(position: $mapPosition) {
            ForEach(annotationsToDisplay) { annotation in
                Annotation(
                    annotation.name,
                    coordinate: annotation.coordinate,
                    anchor: .bottom
                ) {
                    annotationMarkerView(for: annotation)
                }
            }
            // Current location dot
            if let userLocation = locationManager.currentLocation?.coordinate {
                Annotation(
                    "",
                    coordinate: userLocation,
                    anchor: .center
                ) {
                    userLocationMarker
                }
            }
        }
    }
    
    // Annotation marker view with user photos
    private func annotationMarkerView(for annotation: PlaceAnnotation) -> some View {
        // Only highlight annotation if detail sheet is presented AND this is the selected place
        let isSelected = selectedPlaceVM.isDetailSheetPresented && 
                        selectedPlaceVM.selectedPlace?.id.uuidString == annotation.id
        return CustomPlaceAnnotationView(
            annotation: annotation,
            annotationImage: mapViewModel.annotationImages[annotation.id],
            isSelected: isSelected
        )
        .onTapGesture {
            handleAnnotationTap(annotation)
        }
    }
    
    // User location marker
    private var userLocationMarker: some View {
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
    
    // Handle annotation tap
    private func handleAnnotationTap(_ annotation: PlaceAnnotation) {
        Task {
            if let place = await mapViewModel.loadPlaceDetails(for: annotation) {
                await MainActor.run {
                    // Don't animate map when tapping annotation - user is already looking at it
                    selectedPlaceVM.selectPlace(place, shouldAnimateMap: false)
                    selectedPlaceVM.isDetailSheetPresented = true
                }
            }
        }
    }
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        
        ZStack {
            MapReader { mapProxy in
                mapContentView
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
                        selectedPlaceVM.allowAutoPresent = true // Allow auto-present for newly created places
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
                mapViewModel.onMapRegionChange(region)
                hasLoadedInitialViewport = true
            }
        }
         .onDisappear {
             // Remove notification observers
             removeNotificationObservers()
         }
        .task {
            // Load followed users' photos for custom annotations
            await mapViewModel.loadFollowedUsersPhotos()
            
            // 🚀 CRITICAL: Load viewport places FIRST (instant map rendering)
            if !hasLoadedInitialViewport {
                // Give the map a moment to settle and provide a region
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                if let region = currentMapRegion {
                    mapViewModel.onMapRegionChange(region)
                    hasLoadedInitialViewport = true
                } else {
                    // Create a region from the current map position
                    let coords = locationManager.currentLocation?.coordinate ?? defaultCenter
                    let region = MKCoordinateRegion(
                        center: coords,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                    mapViewModel.onMapRegionChange(region)
                    hasLoadedInitialViewport = true
                }
            }
            
            // ✅ REMOVED: Duplicate operations already handled in DataManager
            // profile.refreshUserPlaces() - Already done in DataManager.initializeProfileData()
            // detailPlaceVM.calculateAnnotationPlaces() - Already done in DataManager.calculateMapAnnotations()
            
            // Only refresh place types (not done elsewhere)
            Task.detached(priority: .background) {
                await placeTypeFilterVM.refreshMostFrequentTypes()
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
            // ✅ OPTIMIZED: Only refresh what's needed when notified
            Task {
                // Only refresh place types and filtered places (other data already loaded)
                await placeTypeFilterVM.refreshMostFrequentTypes()
                await MainActor.run {
                    placeTypeFilterVM.updateFilteredPlaces()
                }
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
