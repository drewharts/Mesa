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
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var userSession: UserSession
    
    @Binding var mapPosition: MapCameraPosition
    @Binding var recenterMap: Bool
    @Binding var isSearchExpanded: Bool
    @Binding var isCreatePlacePopupActive: Bool
    
    let selectedPlaceViewModel: SelectedPlaceViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let profileViewModel: ProfileViewModel
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
        onMapTap: @escaping () -> Void
    ) {
        self._mapPosition = mapPosition
        self._recenterMap = recenterMap
        self._isSearchExpanded = isSearchExpanded
        self._isCreatePlacePopupActive = isCreatePlacePopupActive
        self.selectedPlaceViewModel = selectedPlaceViewModel
        self.detailPlaceViewModel = detailPlaceViewModel
        self.profileViewModel = profileViewModel
        self.onMapTap = onMapTap
        
        // Create MapViewModel scoped to this container
        let mapVM = MapViewModel(
            placeService: placeService,
            detailPlaceVM: detailPlaceViewModel
        )
        
        // Wire up ProfileViewModel to MapViewModel for viewport filtering and profile photos
        mapVM.profileViewModel = profileViewModel
        
        self._mapViewModel = StateObject(wrappedValue: mapVM)
    }
    
    var body: some View {
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
        .ignoresSafeArea()
        .edgesIgnoringSafeArea(.all)
        .onChange(of: isSearchExpanded) { oldValue, newValue in
            // Pause loading when search is expanded, resume when minimized
            if newValue {
                // Search is expanded - pause loading
                mapViewModel.pauseLoading()
            } else {
                // Search is minimized - resume loading
                mapViewModel.resumeLoading()
            }
        }
    }
}

