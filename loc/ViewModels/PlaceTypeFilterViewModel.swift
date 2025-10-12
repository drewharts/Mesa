//
//  PlaceTypeFilterViewModel.swift
//  loc
//
//  Created by Assistant on 1/9/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PlaceTypeFilterViewModel: ObservableObject {
    @Published var selectedPlaceTypes: Set<String> = []
    @Published var mostFrequentTypes: [String] = []
    @Published var availableTypes: [String] = []
    @Published var isCalculatingTypes: Bool = false
    @Published var filteredPlaces: [DetailPlace] = []  // CACHED for performance
    
    private let detailPlaceVM: DetailPlaceViewModel
    private let profileVM: ProfileViewModel
    private var cancellables = Set<AnyCancellable>()
    private var recalculationTimer: Timer?
    
    // Optional MapViewModel for viewport places
    weak var mapViewModel: MapViewModel?
    
    init(detailPlaceVM: DetailPlaceViewModel, profileVM: ProfileViewModel) {
        self.detailPlaceVM = detailPlaceVM
        self.profileVM = profileVM
        self.availableTypes = PlaceTypes.recognizedTypes
        
        // Set up observers to recalculate when profile data changes
        setupProfileDataObservers()
        
        // Calculate immediately in case data is already available
        calculateMostFrequentTypes()
        updateFilteredPlaces()
        
        // Set up periodic recalculation for the first 10 seconds to handle async loading
        startPeriodicRecalculation()
    }
    
    private func setupProfileDataObservers() {
        // Watch for changes to selected place types - update filtered places
        $selectedPlaceTypes
            .sink { [weak self] _ in
                self?.updateFilteredPlaces()
            }
            .store(in: &cancellables)
        
        // Watch for changes to user favorites
        profileVM.$userFavorites
            .dropFirst() // Skip initial empty value
            .sink { [weak self] favorites in
                self?.calculateMostFrequentTypes()
                self?.updateFilteredPlaces()
            }
            .store(in: &cancellables)
        
        // Watch for changes to user lists places
        profileVM.$userListsPlaces
            .dropFirst() // Skip initial empty value
            .sink { [weak self] listsPlaces in
                self?.calculateMostFrequentTypes()
                self?.updateFilteredPlaces()
            }
            .store(in: &cancellables)
        
        // Watch for changes to detail places (when places are loaded)
        detailPlaceVM.$places
            .dropFirst()
            .sink { [weak self] places in
                self?.calculateMostFrequentTypes()
                self?.updateFilteredPlaces()
            }
            .store(in: &cancellables)
        
        // Watch for changes to place types (when place types are calculated)
        detailPlaceVM.$placeTypes
            .dropFirst() // Skip initial empty value
            .sink { [weak self] placeTypes in
                self?.calculateMostFrequentTypes()
                self?.updateFilteredPlaces()
            }
            .store(in: &cancellables)
    }
    
    /// Setup observer for MapViewModel viewport changes
    func observeMapViewModel() {
        guard let mapVM = mapViewModel else { return }
        
        mapVM.$viewportPlaces
            .sink { [weak self] _ in
                self?.updateFilteredPlaces()
            }
            .store(in: &cancellables)
    }
    
    private func startPeriodicRecalculation() {
        // Recalculate every 2 seconds for the first 10 seconds to handle async loading
        var attempts = 0
        recalculationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            attempts += 1
            
            // Use Task to call main actor method from timer closure
            Task { @MainActor in
                self?.calculateMostFrequentTypes()
                
                // Stop after 5 attempts (10 seconds)
                if attempts >= 5 {
                    timer.invalidate()
                    self?.recalculationTimer = nil
                }
            }
        }
    }
    
    // MARK: - Type Selection Management
    
    func togglePlaceType(_ type: String) {
        if selectedPlaceTypes.contains(type) {
            selectedPlaceTypes.remove(type)
        } else {
            selectedPlaceTypes.insert(type)
        }
    }
    
    func clearAllFilters() {
        selectedPlaceTypes.removeAll()
    }
    
    func selectPlaceType(_ type: String) {
        selectedPlaceTypes.insert(type)
    }
    
    // MARK: - Most Frequent Types Calculation
    
    func calculateMostFrequentTypes() {
        guard !isCalculatingTypes else { 
            return 
        }
        
        DispatchQueue.main.async {
            self.isCalculatingTypes = true
        }
        
        let allPlaceIds = getAllUserPlaceIds()
        var typeCounts: [String: Int] = [:]
        
        // If we have no places yet, try again later
        if allPlaceIds.isEmpty {
            DispatchQueue.main.async {
                self.isCalculatingTypes = false
            }
            return
        }
        
        // Ensure place types are calculated for all places
        for placeId in allPlaceIds {
            if let place = detailPlaceVM.places[placeId] {
                // Calculate place type if not already done
                if detailPlaceVM.placeTypes[placeId] == nil {
                    detailPlaceVM.calculateRestaurantType(for: place)
                }
                
                if let type = detailPlaceVM.placeTypes[placeId] {
                    // Exclude "Place" from being counted as a filter option
                    // since it should never be filtered out
                    if type != "Place" {
                        typeCounts[type, default: 0] += 1
                    }
                }
            }
        }
        
        // Sort by frequency and take top 8
        let previousTypes = mostFrequentTypes
        let newTypes = typeCounts
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { $0.key }
        
        DispatchQueue.main.async {
            self.mostFrequentTypes = newTypes
        }
        
        // Only update if there are significant changes
        if newTypes != previousTypes {
            // Types updated - no logging needed for production
        }
        
        DispatchQueue.main.async {
            self.isCalculatingTypes = false
        }
    }
    
    func refreshMostFrequentTypes() {
        calculateMostFrequentTypes()
    }
    
    private func getAllUserPlaceIds() -> [String] {
        var allPlaceIds = Set(profileVM.userFavorites)
        
        for listPlaces in profileVM.userListsPlaces.values {
            allPlaceIds.formUnion(listPlaces)
        }
        
        return Array(allPlaceIds)
    }
    
    // MARK: - Filtering Logic
    
    /// Update the cached filtered places (called when data changes)
    func updateFilteredPlaces() {
        // Get all places to display (viewport + saved places)
        let allPlaces = getAllDisplayPlaces()
        
        guard !selectedPlaceTypes.isEmpty else {
            filteredPlaces = allPlaces
            return
        }
        
        // First pass: Calculate missing place types on-demand for filtering
        let placesToCalculate = allPlaces.filter { place in
            detailPlaceVM.placeTypes[place.id.uuidString] == nil
        }
        
        if !placesToCalculate.isEmpty {
            // Calculate types synchronously for immediate filtering results
            for place in placesToCalculate {
                _ = detailPlaceVM.calculateRestaurantTypeSync(for: place)
            }
        }
        
        // Second pass: Apply filtering with all types calculated
        filteredPlaces = allPlaces.filter { place in
            let placeId = place.id.uuidString
            
            guard let placeType = detailPlaceVM.placeTypes[placeId] else { 
                return false 
            }
            
            return shouldIncludePlaceType(placeType)
        }
    }
    
    /// DEPRECATED: Use filteredPlaces @Published property instead
    /// Kept for backward compatibility
    func getFilteredPlaces() -> [DetailPlace] {
        return filteredPlaces
    }
    
    /// Get all places to display (combines viewport places with user's saved places)
    private func getAllDisplayPlaces() -> [DetailPlace] {
        // If we have a MapViewModel, use its combined places
        if let mapVM = mapViewModel {
            return mapVM.getAllDisplayPlaces()
        }
        
        // Fallback to saved places only (for non-map views)
        return detailPlaceVM.savedDetailPlaces
    }
    
    // Helper method to determine if a place type should be included based on selected filters
    private func shouldIncludePlaceType(_ placeType: String) -> Bool {
        // Direct match - if the place type is directly selected
        if selectedPlaceTypes.contains(placeType) {
            return true
        }
        
        // If "Restaurant" is selected, include all restaurant/cuisine types
        if selectedPlaceTypes.contains("Restaurant") {
            let isRestaurantType = PlaceTypes.restaurantTypes.contains(placeType)
            if isRestaurantType {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Search Integration
    
    func filterBySearchText(_ searchText: String) {
        guard !searchText.isEmpty else {
            clearAllFilters()
            return
        }
        
        let matchingTypes = availableTypes.filter { type in
            type.lowercased().contains(searchText.lowercased())
        }
        
        if matchingTypes.count == 1 {
            selectPlaceType(matchingTypes[0])
        } else if matchingTypes.count <= 5 {
            selectedPlaceTypes = Set(matchingTypes)
        }
    }
    
    // MARK: - UI State
    
    var isFiltering: Bool {
        !selectedPlaceTypes.isEmpty
    }
    
    var selectedTypesDisplayText: String {
        if selectedPlaceTypes.isEmpty {
            return "All Places"
        } else if selectedPlaceTypes.count == 1 {
            let selectedType = selectedPlaceTypes.first!
            // Show more descriptive text for Restaurant filter
            if selectedType == "Restaurant" {
                return "Restaurants & Food"
            }
            return selectedType
        } else {
            return "\(selectedPlaceTypes.count) Types"
        }
    }
    
    deinit {
        recalculationTimer?.invalidate()
    }
} 