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
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession

    @Binding var recenterMap: Bool
    @Binding var mapPosition: MapCameraPosition
    @Binding var isCreatePlacePopupActive: Bool

    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State private var showCreatePlacePopup = false
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    @State private var mapRefreshToggle = false
    @State private var showVisiblePlacesPopup = false
    @State private var currentMapRegion: MKCoordinateRegion?
    @State private var hasCenteredOnUserLocation = false
    
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?
    
    // Check when a place is actively selected (detail sheet, any popup, or feed navigation)
    private var isPlaceSelected: Bool {
        selectedPlaceVM.isDetailSheetPresented ||
        selectedPlaceVM.selectedPlace != nil ||
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

    // Community markers filtered to exclude the currently selected place
    private var filteredCommunityMarkers: [CommunityPlaceMarker] {
        let selectedId = selectedPlaceVM.selectedPlace?.id.uuidString
        guard let selectedId else { return mapViewModel.communityMarkers }
        return mapViewModel.communityMarkers.filter { $0.id != selectedId }
    }

    // MARK: - Native Map Annotation Bridging

    /// Merges city/community/network/trip pins and the user-location dot into MapKit's
    /// unified annotation model, respecting the same mutual-exclusivity rules the old
    /// SwiftUI Map content used (trip overlay suppresses the rest; city-zoom suppresses
    /// community+network).
    private var unifiedAnnotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []

        if !mapDisplayCoordinatorVM.hasTripOverlay {
            if mapViewModel.showingCityAnnotations {
                items += mapViewModel.cityAnnotations.map(MapAnnotationItem.init(city:))
            } else {
                if !mapViewModel.showMyPlacesOnly {
                    items += filteredCommunityMarkers.map(MapAnnotationItem.init(community:))
                }
                items += sortedAnnotations.map(MapAnnotationItem.init(network:))
            }
        }

        items += mapDisplayCoordinatorVM.activeTripAnnotations.map(MapAnnotationItem.init(trip:))

        if let userLocation = locationManager.currentLocation?.coordinate {
            items.append(MapAnnotationItem(userLocation: userLocation))
        }

        return items
    }

    /// Determines whether a given unified annotation represents the currently selected place.
    /// Compares by the layer's own place identifier rather than the annotation's stableId, since
    /// a place can be freshly tapped while still rendered under its original layer (e.g. a
    /// community marker, before the async lookup swaps it to a preserved network annotation) —
    /// matching by placeId keeps the highlight correct immediately, not just after that swap.
    /// Trip pins use their own selection concept (mapDisplayCoordinatorVM.selectedTripAnnotationPlaceId)
    /// since trip mode suppresses the normal selectedPlaceVM-driven flow entirely. City pins are
    /// never treated as "selected" — tapping one navigates away rather than opening a detail sheet.
    private func isAnnotationSelected(_ item: MapAnnotationItem) -> Bool {
        switch item.layer {
        case .network, .community:
            guard let selectedId = selectedPlaceVM.selectedPlace?.id.uuidString else { return false }
            return item.placeId == selectedId
        case .trip(let trip):
            return trip.placeId == mapDisplayCoordinatorVM.selectedTripAnnotationPlaceId
        case .city, .userLocation:
            return false
        }
    }

    /// Resolves the correct image for a unified annotation item, reusing the existing
    /// precomputed profile-photo composite cache where available and MapMarkerImageFactory
    /// for everything else.
    private func annotationImage(for item: MapAnnotationItem, isSelected: Bool) -> UIImage? {
        switch item.layer {
        case .network(let annotation):
            if mapViewModel.showEmojiAnnotations {
                return MapMarkerImageFactory.shared.emojiCircleImage(placeType: annotation.placeType, isSelected: isSelected)
            }
            if let baked = mapViewModel.annotationImages[annotation.id] {
                return baked
            }
            return MapMarkerImageFactory.shared.emojiCircleImage(placeType: annotation.placeType, isSelected: isSelected)
        case .community(let marker):
            let fontSize: CGFloat
            switch marker.saveCount {
            case 1...5: fontSize = 16
            case 6...20: fontSize = 20
            default: fontSize = 24
            }
            return MapMarkerImageFactory.shared.communityMarkerImage(emoji: marker.emoji, fontSize: fontSize)
        case .city(let city):
            return MapMarkerImageFactory.shared.cityCapsuleImage(city: city, isSelected: isSelected)
        case .trip(let trip):
            return MapMarkerImageFactory.shared.tripPinImage(annotation: trip, isSelected: isSelected)
        case .userLocation:
            return MapMarkerImageFactory.shared.userLocationDotImage()
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
    
    /// Handles annotation tap with immediate navigation, backfilling full details in background.
    private func handleAnnotationTap(_ annotation: PlaceAnnotation) {
        mapViewModel.tapDiscoveryViewModel.resetState()

        if selectedPlaceVM.selectedPlace?.id.uuidString == annotation.id &&
           selectedPlaceVM.isDetailSheetPresented {
            return
        }

        // Immediate haptic feedback on tap
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let place = mapViewModel.resolveAnnotationForNavigation(annotation)
        mapViewModel.setPreservedAnnotation(for: place)
        navigateToPlace(place)

        if !mapViewModel.hasFullDetails(for: annotation) {
            Task {
                if let fullPlace = await mapViewModel.loadPlaceDetails(for: annotation) {
                    selectedPlaceVM.selectPlace(fullPlace, shouldAnimateMap: false)
                }
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
            GoogleMapView(
                mapPosition: $mapPosition,
                annotations: unifiedAnnotations,
                isSatelliteMap: mapViewModel.isSatelliteMap,
                isAnnotationSelected: { item in isAnnotationSelected(item) },
                onCameraSettled: { region in
                    currentMapRegion = region
                    appCoordinator.currentMapRegion = region
                    guard !mapDisplayCoordinatorVM.hasTripOverlay else { return }
                    if let userId = profile.user?.id {
                        Task.detached(priority: .background) {
                            await mapViewModel.onMapCameraSettled(region, userId: userId)
                        }
                    }
                },
                onNetworkTap: { annotation in
                    handleAnnotationTap(annotation)
                },
                onCommunityTap: { marker in
                    handleCommunityMarkerTap(marker)
                },
                onCityTap: { city in
                    mapViewModel.handleCityAnnotationTap(city)
                },
                onTripTap: { placeId in
                    mapDisplayCoordinatorVM.tappedTripPlaceId = placeId
                },
                onLongPressCreatePlace: { coordinate in
                    newPlaceCoordinate = coordinate
                    showCreatePlacePopup = true
                },
                onDiscoveryTap: { coordinate in
                    onMapTap?(coordinate)
                },
                annotationImageProvider: { item, isSelected in
                    annotationImage(for: item, isSelected: isSelected)
                }
            )
            .ignoresSafeArea()
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
                #if DEBUG
                print("[MapCenter] MapView.onChange(currentLocation): new=\(String(describing: newValue?.coordinate)) hasCenteredOnUserLocation=\(hasCenteredOnUserLocation) selectedPlace=\(String(describing: selectedPlaceVM.selectedPlace?.id))")
                #endif
                if !hasCenteredOnUserLocation,
                   let userLocation = newValue?.coordinate,
                   selectedPlaceVM.selectedPlace == nil {
                    hasCenteredOnUserLocation = true
                    withAnimation(.easeInOut(duration: 0.5)) {
                        mapPosition = .camera(MapCamera(centerCoordinate: userLocation, distance: 1500))
                    }

                    // Pre-fetch annotations while camera animates — isRegionCovered prevents
                    // duplicate fetch when onMapCameraChange(.onEnd) fires after animation
                    if let userId = profile.user?.id {
                        let region = MKCoordinateRegion(
                            center: userLocation,
                            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                        )
                        Task.detached(priority: .userInitiated) {
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
            #if DEBUG
            print("[MapCenter] MapView.onAppear: selectedPlace=\(String(describing: selectedPlaceVM.selectedPlace?.id)) currentLocation=\(String(describing: locationManager.currentLocation?.coordinate)) authStatus=\(CLLocationManager().authorizationStatus.rawValue)")
            #endif
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
            // Viewport annotations load automatically via onMapCameraChange(.onEnd)
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
            // Load profile photos for annotation rendering
            // Viewport annotations load via onMapCameraChange(.onEnd) — no need to duplicate here
            guard let userId = profile.user?.id else { return }
            if !mapViewModel.hasLoadedPhotos {
                await mapViewModel.loadFollowedUsersPhotos(
                    userId: userId,
                    currentUserPhotoUrl: profile.user?.profilePhotoURL
                )
            }
        }
        .onChange(of: profile.user?.id) { oldValue, newValue in
            // When user profile becomes available (nil → value), load annotation photos
            // Viewport annotations load via onMapCameraChange(.onEnd)
            guard let userId = newValue, oldValue == nil else { return }
            Task {
                await mapViewModel.loadFollowedUsersPhotos(
                    userId: userId,
                    currentUserPhotoUrl: profile.user?.profilePhotoURL
                )
            }
        }
        .sheet(isPresented: $showVisiblePlacesPopup) {
            VisiblePlacesPopupView(mapRegion: currentMapRegion)
                .environmentObject(selectedPlaceVM)
                .environmentObject(profile)
                .environmentObject(locationManager)
                .environmentObject(detailPlaceVM)
                .environmentObject(userProfileNavigationVM)
                .environmentObject(userSession)
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

