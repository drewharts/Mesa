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
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel

    @Binding var recenterMap: Bool
    @Binding var mapPosition: MapCameraPosition
    @Binding var isCreatePlacePopupActive: Bool

    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State private var showCreatePlacePopup = false
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    @State private var mapRefreshToggle = false
    @State private var showVisiblePlacesPopup = false
    @State private var currentMapRegion: MKCoordinateRegion?
    @State private var hasLoadedInitialViewport = false
    @State private var hasCenteredOnUserLocation = false
    
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?
    
    // Check when a place is actively selected (detail sheet or any popup)
    private var isPlaceSelected: Bool {
        selectedPlaceVM.isDetailSheetPresented ||
        mapViewModel.showingListPopup ||
        mapViewModel.showingExternalPlacesPopup ||
        mapViewModel.showingReviewsPopup ||
        mapViewModel.showingFavoritesPopup ||
        mapViewModel.showingExternalListPopup ||
        mapViewModel.showingExternalReviewsPopup ||
        mapViewModel.showingExternalFavoritesPopup ||
        mapViewModel.showingKeywordPopup
    }

    // Sort annotations so selected one renders last (on top)
    // MapKit renders annotations in ForEach order, so last = topmost
    // Also includes preserved annotation if it was culled by density reduction
    // In "My Places" mode, filters to only annotations containing the current user
    private var sortedAnnotations: [PlaceAnnotation] {
        let selectedId = selectedPlaceVM.selectedPlace?.id.uuidString

        // Start with viewport annotations, filtered by display mode
        var annotations: [PlaceAnnotation]
        if mapViewModel.showMyPlacesOnly, let userId = mapViewModel.currentUserId {
            annotations = mapViewModel.viewportAnnotations.filter { $0.userIds.contains(userId) }
        } else {
            annotations = mapViewModel.viewportAnnotations
        }

        // Add preserved annotation if not already present (survives zoom-out culling and My Places filter)
        if let preserved = mapViewModel.preservedSelectedAnnotation,
           !annotations.contains(where: { $0.id == preserved.id }) {
            annotations.append(preserved)
        }

        return annotations.sorted { a, b in
            // Selected annotation goes last (renders on top)
            if a.id == selectedId { return false }
            if b.id == selectedId { return true }
            return false // Maintain original order for non-selected
        }
    }

    // Map content extracted to help Swift type checker
    private var mapContentView: some View {
        Map(position: $mapPosition) {
            // Suppress regular annotations when trip overlay is active
            if !mapDisplayCoordinatorVM.hasTripOverlay {
                if mapViewModel.showingCityAnnotations {
                    // City-level annotations (zoomed out)
                    ForEach(mapViewModel.cityAnnotations) { city in
                        Annotation(
                            "",
                            coordinate: city.coordinate,
                            anchor: .center
                        ) {
                            CityAnnotationMarkerView(city: city, isSelected: false)
                                .onTapGesture {
                                    mapViewModel.handleCityAnnotationTap(city)
                                }
                        }
                    }
                } else {
                    // Community places as small emoji markers (shown behind network places)
                    // Hidden in "My Places" mode since community markers are not user-specific
                    // Filter out the community marker that's currently selected (to avoid duplicate with preserved annotation)
                    if !mapViewModel.showMyPlacesOnly {
                        ForEach(mapViewModel.communityMarkers.filter { marker in
                            selectedPlaceVM.selectedPlace?.id.uuidString != marker.id
                        }) { marker in
                            Annotation(
                                "",
                                coordinate: marker.coordinate,
                                anchor: .center
                            ) {
                                communityMarkerView(for: marker)
                            }
                        }
                    }

                    // Network places (user + followed users) as main annotations
                    // Use sortedAnnotations so selected annotation renders last (on top)
                    ForEach(sortedAnnotations) { annotation in
                        Annotation(
                            annotation.name,
                            coordinate: annotation.coordinate,
                            anchor: .bottom
                        ) {
                            annotationMarkerView(for: annotation)
                        }
                    }
                }
            }

            // Trip annotations (shown when viewing a specific trip)
            ForEach(mapDisplayCoordinatorVM.activeTripAnnotations) { annotation in
                Annotation(
                    "",
                    coordinate: annotation.coordinate,
                    anchor: .center
                ) {
                    TripItineraryPinView(
                        annotation: annotation,
                        isSelected: mapDisplayCoordinatorVM.selectedTripAnnotationPlaceId == annotation.placeId,
                        onTap: {
                            mapDisplayCoordinatorVM.tappedTripPlaceId = annotation.placeId
                        }
                    )
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
        // Highlight annotation when it's the selected place and any sheet/popup is open
        let isSelected = isPlaceSelected &&
                        selectedPlaceVM.selectedPlace?.id.uuidString == annotation.id
        return CustomPlaceAnnotationView(
            annotation: annotation,
            annotationImage: mapViewModel.showEmojiAnnotations ? nil : mapViewModel.annotationImages[annotation.id],
            isSelected: isSelected
        )
        .onTapGesture {
            handleAnnotationTap(annotation)
        }
    }

    // Community marker view - small emoji markers for places saved by users you don't follow
    private func communityMarkerView(for marker: CommunityPlaceMarker) -> some View {
        // Check if this marker is selected
        let isSelected = isPlaceSelected &&
                        selectedPlaceVM.selectedPlace?.id.uuidString == marker.id

        // Scale size based on popularity (save count)
        let fontSize: CGFloat = {
            switch marker.saveCount {
            case 1...5: return 16
            case 6...20: return 20
            default: return 24
            }
        }()

        return CommunityMarkerView(
            emoji: marker.emoji,
            fontSize: fontSize,
            isSelected: isSelected
        )
        .onTapGesture {
            handleCommunityMarkerTap(marker)
        }
    }
    
    // Handle community marker tap
    private func handleCommunityMarkerTap(_ marker: CommunityPlaceMarker) {
        // Cancel any in-flight tap discovery (SpatialTapGesture fires simultaneously)
        mapViewModel.tapDiscoveryViewModel.resetState()
        Task {
            if let place = await mapViewModel.loadPlaceDetails(for: marker) {
                await MainActor.run {
                    // Preserve the annotation so it survives zoom-out density culling
                    mapViewModel.setPreservedAnnotation(for: place)
                    // Use selectPlace since data is already complete from backend
                    // Don't animate map when tapping marker - user is already looking at it
                    selectedPlaceVM.selectPlace(place, shouldAnimateMap: false)
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
    
    /// Handles annotation tap with immediate navigation using annotation data,
    /// then backfills full details from the backend in background.
    private func handleAnnotationTap(_ annotation: PlaceAnnotation) {
        // Cancel any in-flight tap discovery (SpatialTapGesture fires simultaneously)
        mapViewModel.tapDiscoveryViewModel.resetState()

        // Skip if this place is already selected AND detail sheet is visible
        if selectedPlaceVM.selectedPlace?.id.uuidString == annotation.id &&
           selectedPlaceVM.isDetailSheetPresented {
            return
        }

        // Use cached full details if available (instant)
        if let cached = mapViewModel.cachedPlaceDetails(for: annotation.id) {
            mapViewModel.setPreservedAnnotation(for: cached)
            navigateToPlace(cached)
            return
        }

        // Navigate immediately with partial data from annotation
        var partialPlace = DetailPlace(
            id: UUID(uuidString: annotation.id) ?? UUID(),
            name: annotation.name,
            address: nil,
            city: nil
        )
        partialPlace.coordinate = annotation.coordinate
        partialPlace.categories = [annotation.placeType]
        mapViewModel.setPreservedAnnotation(for: partialPlace)
        navigateToPlace(partialPlace)

        // Fetch full details in background, then update the selected place
        Task {
            if let fullPlace = await mapViewModel.loadPlaceDetails(for: annotation) {
                selectedPlaceVM.selectPlace(fullPlace, shouldAnimateMap: false)
            }
        }
    }

    /// Routes place navigation through popup sheet or direct detail sheet.
    private func navigateToPlace(_ place: DetailPlace) {
        if mapViewModel.showingListPopup ||
           mapViewModel.showingExternalPlacesPopup ||
           mapViewModel.showingReviewsPopup ||
           mapViewModel.showingFavoritesPopup ||
           mapViewModel.showingExternalListPopup ||
           mapViewModel.showingExternalReviewsPopup ||
           mapViewModel.showingExternalFavoritesPopup ||
           mapViewModel.showingKeywordPopup {
            mapViewModel.pendingPlaceNavigation = place.id.uuidString
        } else {
            selectedPlaceVM.selectPlace(place, shouldAnimateMap: false)
            selectedPlaceVM.isDetailSheetPresented = true
        }
    }
    
    var body: some View {
        ZStack {
            MapReader { mapProxy in
                mapContentView
                .mapStyle(mapViewModel.isSatelliteMap ? .hybrid : .standard)
                .mapControlVisibility(.hidden)
                .ignoresSafeArea()
                .onMapCameraChange(frequency: .onEnd) { context in
                    // This fires only when camera stops moving - Apple handles debouncing!
                    currentMapRegion = context.region

                    // Update global map region for viewport-based searches
                    appCoordinator.currentMapRegion = context.region

                    // Skip viewport fetches when trip annotations are active
                    guard !mapDisplayCoordinatorVM.hasTripOverlay else { return }

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
                    SpatialTapGesture()
                        .onEnded { value in
                            if let coordinate = mapProxy.convert(value.location, from: .local) {
                                onMapTap?(coordinate)
                            }
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
            
            // Visible Places Button
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

            // Tap-to-discover overlay
            tapDiscoveryOverlay
        }
        .sheet(isPresented: $showCreatePlacePopup) {
            if let coordinate = newPlaceCoordinate {
                CreatePlacePopupView(coordinate: coordinate) { name, description in
                    if let userId = profile.user?.id {
                        let generatedId = UUID().uuidString
                        selectedPlaceVM.allowAutoPresent = true
                        selectedPlaceVM.createNewPlace(idString: generatedId, name: name, description: description, coordinate: coordinate, userId: userId, profileVM: profile, detailPlaceVM: detailPlaceVM)
                        newPlaceCoordinate = nil
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
        .onChange(of: selectedPlaceVM.selectedPlace?.id) { oldValue, newValue in
            if newValue == nil {
                // Clear preserved annotation when place is deselected
                mapViewModel.clearPreservedAnnotation()
            } else if oldValue != newValue, let place = selectedPlaceVM.selectedPlace {
                // Set preserved annotation when a new place is selected (e.g., from search)
                // This ensures a pin appears on the map even if the place isn't in viewportAnnotations
                mapViewModel.setPreservedAnnotation(for: place)
            }
        }
        // Re-set annotation when valid coordinates arrive for a place that had invalid coords.
        // MainView handles camera animation; here we ensure the emoji annotation is created.
        .onChange(of: selectedPlaceVM.shouldAnimateMapToPlace) { _, shouldAnimate in
            if shouldAnimate, let place = selectedPlaceVM.selectedPlace {
                mapViewModel.setPreservedAnnotation(for: place)
            }
        }
    }
    
    // Tap-to-discover status overlay (searching / no results)
    private var tapDiscoveryOverlay: some View {
        VStack {
            Spacer()
            Group {
                switch mapViewModel.tapDiscoveryViewModel.discoveryState {
                case .searching:
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Finding place...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale))

                case .noResults:
                    Text("No place found here")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .transition(.opacity.combined(with: .scale))

                default:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: mapViewModel.tapDiscoveryViewModel.discoveryState)
            .padding(.bottom, 120)
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
