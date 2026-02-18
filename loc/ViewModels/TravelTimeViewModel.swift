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

    // MARK: - Menu Expansion State
    /// Controls whether the transport type selection menu is expanded
    @Published private(set) var isMenuExpanded: Bool = false
    /// Currently highlighted menu item index during drag gesture
    @Published private(set) var selectedMenuIndex: Int? = nil

    // MARK: - Private State
    /// Tracks the place ID of the most recent request to discard stale results.
    private var currentRequestPlaceId: UUID?

    // MARK: - Initialization
    init() {
        loadDefaultTransportType()
    }

    // MARK: - Public Methods

    /// Sets the current place, resetting travel time state when the place changes.
    func setPlace(_ place: DetailPlace?) {
        let isNewPlace = self.place?.id != place?.id
        self.place = place
        if isNewPlace {
            currentRequestPlaceId = place?.id
            travelTime = "Calculating..."
            travelTimes = [:]
            collapseMenu()
        }
    }
    
    // MARK: - Travel Time Management

    /// Fetches travel times for all transport modes and updates published state.
    func updateTravelTime(for place: DetailPlace, from userCoordinate: CLLocationCoordinate2D) {
        let requestPlaceId = place.id
        currentRequestPlaceId = requestPlaceId

        guard let placeCoordinate = place.coordinate else {
            travelTime = "N/A"
            travelTimes = [:]
            return
        }

        MapKitService.shared.calculateTravelTimes(from: userCoordinate, to: placeCoordinate) { [weak self] results, error in
            DispatchQueue.main.async {
                guard let self = self, self.currentRequestPlaceId == requestPlaceId else { return }
                self.applyTravelTimeResults(results, error: error)
            }
        }
    }

    /// Applies API results to published state, selecting the best transport mode when needed.
    private func applyTravelTimeResults(_ results: [MapKitService.TransportType: TimeInterval]?, error: Error?) {
        guard let results = results, error == nil else {
            travelTime = "N/A"
            travelTimes = [:]
            return
        }

        var times: [MapKitService.TransportType: String] = [:]
        for (transportType, timeInterval) in results {
            times[transportType] = formattedTime(from: timeInterval)
        }

        travelTimes = times

        if let currentTime = times[currentTransportType] {
            travelTime = currentTime
        } else {
            selectBestAvailableTransportMode()
        }
    }

    /// Formats a time interval in seconds into a human-readable string (e.g. "15 min", "60+ min").
    private func formattedTime(from timeInterval: TimeInterval) -> String {
        let minutes = timeInterval / 60.0
        return minutes > 60 ? "60+ min" : String(format: "%.0f min", minutes)
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
    
    // MARK: - Menu Expansion Control
    
    /// Expands the transport type selection menu
    func expandMenu() {
        isMenuExpanded = true
    }
    
    /// Collapses the transport type selection menu and resets selection state
    func collapseMenu() {
        isMenuExpanded = false
        selectedMenuIndex = nil
    }
    
    /// Updates the highlighted menu item during drag gesture
    /// - Parameter index: The index of the transport type being hovered, or nil if none
    func updateSelectedIndex(_ index: Int?) {
        selectedMenuIndex = index
    }
    
    /// Selects the transport type at the current menu index and collapses the menu
    /// - Returns: true if a selection was made, false otherwise
    @discardableResult
    func confirmMenuSelection() -> Bool {
        defer { collapseMenu() }
        
        guard let index = selectedMenuIndex else { return false }
        
        let transportTypes = MapKitService.TransportType.allCases
        guard index >= 0, index < transportTypes.count else { return false }
        
        let selected = transportTypes[index]
        switchTransportType(to: selected)
        saveDefaultTransportType(selected)
        return true
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

