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
            
        }
        .ignoresSafeArea()
        .edgesIgnoringSafeArea(.all)
        // Native SwiftUI sheet for list popup (replaces custom BottomSheetView)
        // Single Responsibility: Present list popup sheet using native iOS sheet behavior
        // MVVM: Uses ViewModel state to control presentation
        .sheet(isPresented: $mapViewModel.showingListPopup) {
            // Always provide content to prevent competing views issue
            // MVVM: View is declarative - uses ViewModel state to determine content
            if let listId = mapViewModel.selectedListId,
               let list = profileViewModel.lightweightPlaceLists.first(where: { $0.id == listId }),
               let listIndex = profileViewModel.lightweightPlaceLists.firstIndex(where: { $0.id == listId }) {
                LightweightListPopupView(
                    lists: profileViewModel.lightweightPlaceLists,
                    initialListIndex: listIndex
                )
                .environmentObject(profileViewModel)
                .environmentObject(selectedPlaceViewModel)
                .environmentObject(dataManager)
                .presentationDetents([.height(300), .height(800)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.clear)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(800)))
                .interactiveDismissDisabled(false)
                .onDisappear {
                    // Clear list filter when popup is dismissed
                    mapViewModel.clearListFilter()
                    profileViewModel.selectedListIdForMap = nil
                }
            } else {
                // Loading state while list is being validated
                // Prevents empty sheet from appearing before content is ready
                VStack {
                    ProgressView()
                        .padding()
                    Text("Loading list...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
                .onDisappear {
                    // Clear state if dismissed during loading
                    mapViewModel.clearListFilter()
                    profileViewModel.selectedListIdForMap = nil
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

