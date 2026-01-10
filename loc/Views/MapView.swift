//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import MapKit

struct MapView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
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
    @State private var hasCenteredOnUserLocation = false
    
    var onMapTap: (() -> Void)?
    
    // Helper computed property to simplify type checking
    private var annotationsToDisplay: [PlaceAnnotation] {
        return mapViewModel.viewportAnnotations
    }
    
    // Map content extracted to help Swift type checker
    private var mapContentView: some View {
        Map(position: $mapPosition) {
            // Community places as small white dots (shown behind network places)
            ForEach(mapViewModel.communityMarkers) { marker in
                Annotation(
                    "",
                    coordinate: marker.coordinate,
                    anchor: .center
                ) {
                    communityMarkerView(for: marker)
                }
            }
            
            // Network places (user + followed users) as main annotations
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
    
    // Community marker view - small emoji markers for places saved by users you don't follow
    private func communityMarkerView(for marker: CommunityPlaceMarker) -> some View {
        let isSelected = selectedPlaceVM.isDetailSheetPresented && 
                        selectedPlaceVM.selectedPlace?.id.uuidString == marker.id
        
        // Scale size based on popularity (save count)
        let fontSize: CGFloat = {
            switch marker.saveCount {
            case 1...5: return 16
            case 6...20: return 20
            default: return 24
            }
        }()
        
        return Text(marker.emoji)
            .font(.system(size: isSelected ? fontSize * 1.8 : fontSize))
            .padding(isSelected ? 8 : 0)
            .background(
                Circle()
                    .fill(Color.white.opacity(isSelected ? 0.95 : 0))
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.8) : Color.clear,
                        radius: isSelected ? 12 : 0
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .zIndex(isSelected ? 100 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .onTapGesture {
                handleCommunityMarkerTap(marker)
            }
    }
    
    // Handle community marker tap
    private func handleCommunityMarkerTap(_ marker: CommunityPlaceMarker) {
        Task {
            if let place = await mapViewModel.loadPlaceDetails(for: marker) {
                await MainActor.run {
                    // Don't animate map when tapping marker - user is already looking at it
                    selectedPlaceVM.selectPlaceAndFetchDetails(place, shouldAnimateMap: false)
                    selectedPlaceVM.isDetailSheetPresented = true
                }
            }
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
                    // Check if list sheet is open - if so, navigate within the sheet instead
                    // MVVM: View coordinates navigation based on ViewModel state
                    if mapViewModel.showingListPopup {
                        // Set pending navigation - LightweightListPopupView will observe this and push to NavigationStack
                        // This makes annotation taps behave the same as clicking a place tile in the list sheet
                        mapViewModel.pendingPlaceNavigation = place.id.uuidString
                    } else {
                        // Normal behavior: show place detail sheet
                        selectedPlaceVM.selectPlaceAndFetchDetails(place, shouldAnimateMap: false)
                        selectedPlaceVM.isDetailSheetPresented = true
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            MapReader { mapProxy in
                mapContentView
                .mapControlVisibility(.hidden)
                .ignoresSafeArea()
                .onMapCameraChange(frequency: .onEnd) { context in
                    // This fires only when camera stops moving - Apple handles debouncing!
                    currentMapRegion = context.region
                    
                    // Only load if user profile is available (View coordinates data flow)
                    if let userId = profile.user?.id {
                        Task.detached(priority: .background) {
                            await mapViewModel.onMapCameraSettled(context.region, userId: userId)
                        }
                    }
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
            .onChange(of: recenterMap) { oldValue, newValue in
                if newValue {
                    let coords = locationManager.currentLocation?.coordinate ?? defaultCenter
                    withAnimation(.easeInOut) {
                        mapPosition = .camera(MapCamera(centerCoordinate: coords, distance: 1000))
                    }
                    recenterMap = false
                }
            }
            .onChange(of: locationManager.currentLocation) { oldValue, newValue in
                // Center map on user's actual location when it first becomes available
                // This fixes the "Kansas problem" where new users start at the US center
                if !hasCenteredOnUserLocation,
                   let userLocation = newValue?.coordinate,
                   selectedPlaceVM.selectedPlace == nil {
                    hasCenteredOnUserLocation = true
                    withAnimation(.easeInOut(duration: 0.5)) {
                        mapPosition = .camera(MapCamera(centerCoordinate: userLocation, distance: 1500))
                    }
                    
                    // Also load viewport places for this new location
                    if !hasLoadedInitialViewport, let userId = profile.user?.id {
                        let region = MKCoordinateRegion(
                            center: userLocation,
                            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                        )
                        hasLoadedInitialViewport = true
                        Task.detached(priority: .background) {
                            await mapViewModel.onMapCameraSettled(region, userId: userId)
                        }
                    }
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
                hasCenteredOnUserLocation = true // Don't override with user location later
            } else if let userLocation = locationManager.currentLocation?.coordinate {
                // User location is available - center on it
                mapPosition = .camera(MapCamera(centerCoordinate: userLocation, distance: 1500))
                hasCenteredOnUserLocation = true
            }
            // Note: If neither place nor location is available, mapPosition stays at .automatic
            // and the onChange(of: locationManager.currentLocation) will handle centering
            // when the user's location becomes available

            // Setup notification observers
            setupNotificationObservers()
            
            // 🚀 Load initial viewport places (only if profile is ready)
            if !hasLoadedInitialViewport, let region = currentMapRegion, let userId = profile.user?.id {
                Task.detached(priority: .background) {
                    await mapViewModel.onMapCameraSettled(region, userId: userId)
                }
                hasLoadedInitialViewport = true
            }
        }
         .onDisappear {
             // Remove notification observers
             removeNotificationObservers()
         }
        .task(id: scenePhase) {
            // Refresh photos when app returns to foreground (e.g., user updated their profile photo)
            if scenePhase == .active, let userId = profile.user?.id {
                await mapViewModel.loadFollowedUsersPhotos(
                    userId: userId,
                    currentUserPhotoUrl: profile.user?.profilePhotoURL
                )
            }
        }
        .task {
            // 🚀 CRITICAL: Load viewport places FIRST (instant map rendering)
            // Only proceed if user profile is available
            guard let userId = profile.user?.id else { return }
            
            if !hasLoadedInitialViewport {
                // Give the map a moment to settle and provide a region
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                if let region = currentMapRegion {
                    await mapViewModel.onMapCameraSettled(region, userId: userId)
                    hasLoadedInitialViewport = true
                } else if let userLocation = locationManager.currentLocation?.coordinate {
                    // Create a region from the user's current location
                    let region = MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                    )
                    await mapViewModel.onMapCameraSettled(region, userId: userId)
                    hasLoadedInitialViewport = true
                }
                // Note: If no location yet, we'll load viewport when location becomes available
                // via the onChange handler
            }
            
            // ✅ Load profile photos for annotations
            if !mapViewModel.hasLoadedPhotos {
                await mapViewModel.loadFollowedUsersPhotos(
                    userId: userId,
                    currentUserPhotoUrl: profile.user?.profilePhotoURL
                )
            }
        }
        .onChange(of: profile.user?.id) { oldValue, newValue in
            // When user profile becomes available (nil → value), trigger initial loads
            guard let userId = newValue, oldValue == nil else { return }
            
            Task {
                // Load photos
                await mapViewModel.loadFollowedUsersPhotos(
                    userId: userId,
                    currentUserPhotoUrl: profile.user?.profilePhotoURL
                )
                
                // Load viewport if we have a region
                if !hasLoadedInitialViewport {
                    if let region = currentMapRegion {
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                        hasLoadedInitialViewport = true
                    } else if let userLocation = locationManager.currentLocation?.coordinate {
                        let region = MKCoordinateRegion(
                            center: userLocation,
                            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                        )
                        await mapViewModel.onMapCameraSettled(region, userId: userId)
                        hasLoadedInitialViewport = true
                    }
                }
            }
        }
        .sheet(isPresented: $showVisiblePlacesPopup) {
            VisiblePlacesPopupView(mapRegion: currentMapRegion)
                .environmentObject(selectedPlaceVM)
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
            // Map annotations are refreshed automatically via viewport loading
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
