//
//  MapViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/20/25.
//


import SwiftUI
import GoogleMaps
import GooglePlaces
import Combine

class MapViewModel: ObservableObject {
    @Published var cameraPosition: GMSCameraPosition
    @Published var markers: [GMSMarker] = []
    @Published var selectedPlace: GMSPlace?
    @Published var shouldClearSearchResults: Bool = false
    @Published var shouldCenterOnUser: Bool = true

    private let placesClient: GMSPlacesClient
    private let locationManager: LocationManager
    private var userSession: UserSession
    private var cancellables = Set<AnyCancellable>()
    private var selectedPlaceCancellable: AnyCancellable?

    // Add a reference to the GMSMapView:
    weak var mapView: GMSMapView?

    init(
        placesClient: GMSPlacesClient = .shared(),
        locationManager: LocationManager,
        userSession: UserSession,
        searchViewModel: SearchViewModel? = nil
    ) {
        self.placesClient = placesClient
        self.locationManager = locationManager
        self.userSession = userSession

        // Default camera position
        cameraPosition = GMSCameraPosition.camera(
            withLatitude: 0,
            longitude: 0,
            zoom: 1.0
        )

        setupSubscriptions()

        // Subscribe to selectedPlacePublisher from SearchViewModel
        if let searchViewModel = searchViewModel {
            selectedPlaceCancellable = searchViewModel.$selectedPlace
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] place in
                    self?.selectedPlace = place
                    // Update camera position directly using animate:
                    self?.mapView?.animate(to: GMSCameraPosition.camera(
                        withLatitude: place.coordinate.latitude,
                        longitude: place.coordinate.longitude,
                        zoom: 15.0
                    ))
                    self?.addMarker(for: place)
                }
        }
    }

    func recenterUser(){
        if let currentLocation = locationManager.currentLocation {
            // Update camera position directly using animate:
            mapView?.animate(to: GMSCameraPosition.camera(
                withLatitude: currentLocation.coordinate.latitude,
                longitude: currentLocation.coordinate.longitude,
                zoom: 15.0
            ))
            shouldCenterOnUser = false
        }
    }

    private func setupSubscriptions() {
        // React to changes in user session
        userSession.objectWillChange
            .sink { [weak self] in
                self?.loadMarkers()
            }
            .store(in: &cancellables)
    }

    func loadMarkers() {
        markers.removeAll() // Clear existing markers
        guard let placeListVMs = userSession.profileViewModel?.placeListViewModels else { return }

        for listVM in placeListVMs {
            for place in listVM.placeList.places {
                fetchPlaceDetails(for: place.id)
            }
        }
    }

    private func fetchPlaceDetails(for placeID: String) {
        placesClient.fetchPlace(
            fromPlaceID: placeID,
            placeFields: [.coordinate, .name],
            sessionToken: nil
        ) { [weak self] fetchedPlace, error in
            if let error = error {
                print("Error fetching place: \(error)")
                return
            }
            guard let fetchedPlace = fetchedPlace else { return }
            self?.addMarker(for: fetchedPlace)
        }
    }

    private func addMarker(for place: GMSPlace) {
        let marker = GMSMarker(position: place.coordinate)
        marker.title = place.name
        markers.append(marker)
    }

    func onMapMoved() {
        // Indicate to the View that search results should be cleared
        shouldClearSearchResults = true
    }
    
    func resetClearSearchResults() {
        // Reset the flag after the View has cleared the results
        shouldClearSearchResults = false
    }
}
