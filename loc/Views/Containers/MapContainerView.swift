//
//  MapContainerView.swift
//  loc
//
//  Created by Cursor on 11/13/25.
//

import SwiftUI
import MapKit

/// Container that owns MapViewModel and handles all map-related logic
struct MapContainerView: View {
    @StateObject private var mapViewModel: MapViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userSession: UserSession
    
    @Binding var mapPosition: MapCameraPosition
    @Binding var recenterMap: Bool
    @Binding var isSearchExpanded: Bool
    @Binding var isCreatePlacePopupActive: Bool
    
    let selectedPlaceViewModel: SelectedPlaceViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let profileViewModel: ProfileViewModel
    let dataManager: DataManager
    let userProfileViewModel: UserProfileViewModel
    let serviceContainer: ServiceContainer
    let notificationManager: NotificationManager
    let onMapTap: () -> Void
    
    init(
        mapPosition: Binding<MapCameraPosition>,
        recenterMap: Binding<Bool>,
        isSearchExpanded: Binding<Bool>,
        isCreatePlacePopupActive: Binding<Bool>,
        selectedPlaceViewModel: SelectedPlaceViewModel,
        detailPlaceViewModel: DetailPlaceViewModel,
        placeService: PlaceService,
        profileViewModel: ProfileViewModel,
        dataManager: DataManager,
        userProfileViewModel: UserProfileViewModel,
        serviceContainer: ServiceContainer,
        notificationManager: NotificationManager,
        onMapTap: @escaping () -> Void
    ) {
        self._mapPosition = mapPosition
        self._recenterMap = recenterMap
        self._isSearchExpanded = isSearchExpanded
        self._isCreatePlacePopupActive = isCreatePlacePopupActive
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.detailPlaceViewModel = detailPlaceViewModel
        self.profileViewModel = profileViewModel
        self.dataManager = dataManager
        self.userProfileViewModel = userProfileViewModel
        self.serviceContainer = serviceContainer
        self.notificationManager = notificationManager
        self.onMapTap = onMapTap
        
        // Create MapViewModel scoped to this container
        // Note: MapViewModel no longer observes ProfileViewModel directly
        // The View layer coordinates data flow between ViewModels (SRP pattern)
        let mapVM = MapViewModel(
            placeService: placeService,
            detailPlaceVM: detailPlaceViewModel
        )
        
        self._mapViewModel = StateObject(wrappedValue: mapVM)
    }
    
    var body: some View {
        ZStack {
        MapView(
            recenterMap: $recenterMap,
            mapPosition: $mapPosition,
            isSearchBarMinimized: !isSearchExpanded,
            isCreatePlacePopupActive: $isCreatePlacePopupActive,
            onMapTap: onMapTap
        )
        .environmentObject(mapViewModel)
        .environmentObject(selectedPlaceViewModel)
        .environmentObject(detailPlaceViewModel)
        .environmentObject(profileViewModel)
            .onChange(of: profileViewModel.selectedListIdForMap) { oldValue, newValue in
                // Sync ProfileViewModel list selection with MapViewModel
                // MVVM: View coordinates data flow between ViewModels
                if let listId = newValue {
                    // Validate list exists before showing sheet (prevents competing views)
                    mapViewModel.selectList(listId, availableLists: profileViewModel.lightweightPlaceLists)
                    // Trigger reload if we have a current region
                    if let userId = userSession.currentUserId {
                        let currentRegion = getCurrentMapRegion()
                        Task {
                            if let region = currentRegion {
                                await mapViewModel.onMapCameraSettled(region, userId: userId)
                            }
                        }
                    }
                } else {
                    mapViewModel.clearListFilter()
                    // Trigger reload to show all annotations
                    if let userId = userSession.currentUserId {
                        let currentRegion = getCurrentMapRegion()
                        Task {
                            if let region = currentRegion {
                                await mapViewModel.onMapCameraSettled(region, userId: userId)
                            }
                        }
                    }
                }
            }
            .onChange(of: profileViewModel.showTikToksOnMap) { _, newValue in
                // Navigate to map showing TikTok places
                if newValue {
                    mapViewModel.selectTikToks()
                    profileViewModel.showTikToksOnMap = false // Reset trigger
                    // Trigger reload with TikTok filter
                    if let userId = userSession.currentUserId {
                        let currentRegion = getCurrentMapRegion()
                        Task {
                            if let region = currentRegion {
                                await mapViewModel.onMapCameraSettled(region, userId: userId)
                            }
                        }
                    }
                }
            }
            .onChange(of: profileViewModel.showReviewsOnMap) { _, newValue in
                // Navigate to map showing reviewed places
                if newValue {
                    mapViewModel.selectReviews()
                    profileViewModel.showReviewsOnMap = false // Reset trigger
                    // Trigger reload with reviews filter
                    if let userId = userSession.currentUserId {
                        let currentRegion = getCurrentMapRegion()
                        Task {
                            if let region = currentRegion {
                                await mapViewModel.onMapCameraSettled(region, userId: userId)
                            }
                        }
                    }
                }
            }

        }
        .ignoresSafeArea()
        .edgesIgnoringSafeArea(.all)
        // Native SwiftUI sheet for list popup (replaces custom BottomSheetView)
        // Single Responsibility: Present list popup sheet using native iOS sheet behavior
        // MVVM: Uses ViewModel state to control presentation
        .onChange(of: selectedPlaceViewModel.isDetailSheetPresented) { oldValue, newValue in
            // Monitor detail sheet presentation state for debugging if needed
        }
        // Single sheet using item binding - prevents "only presenting a single sheet" warning
        .sheet(item: $mapViewModel.activeSheet) { sheetType in
            Group {
                switch sheetType {
                case .list(let listId):
                    if let listIndex = profileViewModel.lightweightPlaceLists.firstIndex(where: { $0.id == listId }) {
                        LightweightListPopupView(
                            lists: profileViewModel.lightweightPlaceLists,
                            initialListIndex: listIndex
                        )
                        .id(listId)
                    } else {
                        // Loading state while list is being validated
                        VStack {
                            ProgressView()
                                .padding()
                            Text("Loading list...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                case .tiktoks:
                    TikToksPopupView()

                case .reviews:
                    ReviewsListPopupView()
                }
            }
            .environmentObject(profileViewModel)
            .environmentObject(selectedPlaceViewModel)
            .environmentObject(detailPlaceViewModel)
            .environmentObject(mapViewModel)
            .environmentObject(dataManager)
            .environmentObject(locationManager)
            .environmentObject(userSession)
            .environmentObject(userProfileViewModel)
            .environmentObject(serviceContainer)
            .environmentObject(notificationManager)
            .presentationDetents([.height(300), .height(800)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.clear)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(800)))
            .onDisappear {
                // Clear all filters when any sheet is dismissed
                mapViewModel.clearAllFilters()
                profileViewModel.selectedListIdForMap = nil

                // Trigger map annotation reload to show all annotations
                if let userId = userSession.currentUserId {
                    let currentRegion = getCurrentMapRegion()
                    Task {
                        if let region = currentRegion {
                            await mapViewModel.onMapCameraSettled(region, userId: userId)
                        }
                    }
                }
            }
        }
    }

    /// Helper to get current map region from location manager or default
    private func getCurrentMapRegion() -> MKCoordinateRegion? {
        // Use location manager's current location as the center
        if let location = locationManager.currentLocation?.coordinate {
            return MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.1,
                    longitudeDelta: 0.1
                )
            )
        }
        // Fallback to default center if no location available
        let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
        return MKCoordinateRegion(
            center: defaultCenter,
            span: MKCoordinateSpan(
                latitudeDelta: 0.1,
                longitudeDelta: 0.1
            )
        )
    }
}

