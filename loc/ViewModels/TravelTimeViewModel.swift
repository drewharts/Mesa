//
//  TravelTimeViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Smart ViewModel for travel time calculation and transport mode management
//

import Foundation
import MapKit
import Combine

@MainActor
class TravelTimeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var travelTime: String = "Calculating..."
    @Published var currentTransportType: MapKitService.TransportType = .automobile
    @Published var travelTimes: [MapKitService.TransportType: String] = [:]
    @Published var place: DetailPlace?
    
    // MARK: - Dependencies
    private let selectedPlaceVM: SelectedPlaceViewModel  // Temporary until fully refactored
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(selectedPlaceVM: SelectedPlaceViewModel) {
        self.selectedPlaceVM = selectedPlaceVM
        loadDefaultTransportType()
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe place changes
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                self?.place = place
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Travel Time Management
    func updateTravelTime(for place: DetailPlace, from userCoordinate: CLLocationCoordinate2D) {
        // Unwrap the coordinate; if it's nil, set travelTime to "N/A" and return.
        guard let placeCoordinate = place.coordinate else {
            print("⚠️ [TravelTimeViewModel] Cannot calculate travel time - place '\(place.name)' has no coordinates")
            travelTime = "N/A"
            travelTimes = [:]
            return
        }
        

        // Calculate travel times for all transport types
        MapKitService.shared.calculateTravelTimes(from: userCoordinate, to: placeCoordinate) { [weak self] results, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    self.travelTime = "N/A"
                    self.travelTimes = [:]
                } else if let results = results {
                    var times: [MapKitService.TransportType: String] = [:]

                    for (transportType, timeInterval) in results {
                        let minutes = timeInterval / 60.0
                        let timeString = minutes > 60 ? "60+ min" : String(format: "%.0f min", minutes)
                        times[transportType] = timeString
                    }

                    self.travelTimes = times

                    // Set the current travel time based on current transport type
                    if let currentTime = times[self.currentTransportType] {
                        self.travelTime = currentTime
                    } else {
                        // Default transport type not available - find best alternative
                        self.selectBestAvailableTransportMode()
                    }
                } else {
                    self.travelTime = "N/A"
                    self.travelTimes = [:]
                }
            }
        }
    }
    
    func switchTransportType(to transportType: MapKitService.TransportType) {
        self.currentTransportType = transportType
        if let timeString = travelTimes[transportType] {
            self.travelTime = timeString
        } else {
            self.travelTime = "Calculating..."
        }
    }
    
    // MARK: - Smart Transport Selection
    
    /// Selects the transport mode with the shortest available time when the default mode is unavailable.
    /// This provides a better UX by showing a useful time instead of "N/A" when possible.
    private func selectBestAvailableTransportMode() {
        // Find the transport type with the shortest valid time
        let validTimes = travelTimes.compactMap { (type, timeString) -> (MapKitService.TransportType, TimeInterval)? in
            // Parse the time string to get actual duration
            guard let duration = parseTimeString(timeString) else { return nil }
            return (type, duration)
        }
        
        // Sort by duration and pick the shortest
        if let bestOption = validTimes.min(by: { $0.1 < $1.1 }) {
            let bestType = bestOption.0
            let bestTimeString = travelTimes[bestType] ?? "N/A"
            
            // Switch to the best available option
            currentTransportType = bestType
            travelTime = bestTimeString
        } else {
            // No valid times available at all
            travelTime = "N/A"
        }
    }
    
    /// Parses a time string (e.g., "15 min", "60+ min") into TimeInterval (seconds)
    /// Returns nil if the string cannot be parsed or represents an invalid time
    private func parseTimeString(_ timeString: String) -> TimeInterval? {
        // Handle "60+ min" case
        if timeString.hasPrefix("60+") {
            return 60 * 60 // 60 minutes in seconds
        }
        
        // Handle "N/A" or empty strings
        if timeString == "N/A" || timeString.isEmpty {
            return nil
        }
        
        // Parse "XX min" format
        let components = timeString.components(separatedBy: " ")
        guard components.count >= 1,
              let minutes = Double(components[0]) else {
            return nil
        }
        
        return minutes * 60 // Convert to seconds
    }
    
    private func loadDefaultTransportType() {
        let savedTypeRaw = UserDefaults.standard.integer(forKey: "defaultTransportType")
        if let transportType = MapKitService.TransportType(rawValue: savedTypeRaw) {
            currentTransportType = transportType
        } else {
            currentTransportType = .automobile // Default to automobile
        }
    }

    func saveDefaultTransportType(_ transportType: MapKitService.TransportType) {
        UserDefaults.standard.set(transportType.rawValue, forKey: "defaultTransportType")
        currentTransportType = transportType
    }
    
    func openNavigation(for place: DetailPlace, currentLocation: CLLocationCoordinate2D) {
        // Unwrap the coordinate
        guard let destinationCoordinate = place.coordinate else {
            print("No coordinate available for this place.")
            return
        }

        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        destinationMapItem.name = place.name

        // Create a map item for the current location.
        let currentLocationMapItem = MKMapItem.forCurrentLocation()

        // Define launch options based on current transport type.
        var launchOptions: [String: Any] = [:]
        
        switch currentTransportType {
        case .automobile:
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        case .walking:
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        case .transit:
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit]
        case .bicycle:
            // MapKit doesn't have bicycle directions, so we'll use walking directions
            // which is better than driving directions for cyclists
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        }

        // Launch Apple Maps with the specified options.
        MKMapItem.openMaps(with: [currentLocationMapItem, destinationMapItem], launchOptions: launchOptions)
    }
}

