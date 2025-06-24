//
//  PlaceTypeFilterViewModel.swift
//  loc
//
//  Created by Assistant on 1/9/25.
//

import Foundation
import SwiftUI

@MainActor
class PlaceTypeFilterViewModel: ObservableObject {
    @Published var selectedPlaceTypes: Set<String> = []
    @Published var mostFrequentTypes: [String] = []
    @Published var availableTypes: [String] = []
    
    private let detailPlaceVM: DetailPlaceViewModel
    private let profileVM: ProfileViewModel
    
    init(detailPlaceVM: DetailPlaceViewModel, profileVM: ProfileViewModel) {
        self.detailPlaceVM = detailPlaceVM
        self.profileVM = profileVM
        self.availableTypes = PlaceTypes.recognizedTypes
    }
    
    // MARK: - Type Selection Management
    
    func togglePlaceType(_ type: String) {
        if selectedPlaceTypes.contains(type) {
            selectedPlaceTypes.remove(type)
            print("❌ Removed filter: \(type)")
        } else {
            selectedPlaceTypes.insert(type)
            print("✅ Added filter: \(type)")
        }
    }
    
    func clearAllFilters() {
        selectedPlaceTypes.removeAll()
        print("🧹 Cleared all filters")
    }
    
    func selectPlaceType(_ type: String) {
        selectedPlaceTypes.insert(type)
        print("✅ Selected filter: \(type)")
    }
    
    // MARK: - Most Frequent Types Calculation
    
    func calculateMostFrequentTypes() {
        let allPlaceIds = getAllUserPlaceIds()
        var typeCounts: [String: Int] = [:]
        
        print("🔍 Calculating most frequent types from \(allPlaceIds.count) places")
        
        // Ensure place types are calculated for all places
        for placeId in allPlaceIds {
            if let place = detailPlaceVM.places[placeId] {
                // Calculate place type if not already done
                if detailPlaceVM.placeTypes[placeId] == nil {
                    detailPlaceVM.calculateRestaurantType(for: place)
                }
                
                if let type = detailPlaceVM.placeTypes[placeId] {
                    typeCounts[type, default: 0] += 1
                }
            }
        }
        
        // Sort by frequency and take top 8
        mostFrequentTypes = typeCounts
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { $0.key }
        
        print("📊 Most frequent types: \(mostFrequentTypes)")
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
    
    func getFilteredPlaces() -> [DetailPlace] {
        guard !selectedPlaceTypes.isEmpty else {
            return detailPlaceVM.savedDetailPlaces
        }
        
        let filteredPlaces = detailPlaceVM.savedDetailPlaces.filter { place in
            let placeId = place.id.uuidString
            guard let placeType = detailPlaceVM.placeTypes[placeId] else { return false }
            return selectedPlaceTypes.contains(placeType)
        }
        
        print("🔍 Filtered \(detailPlaceVM.savedDetailPlaces.count) places to \(filteredPlaces.count) places")
        return filteredPlaces
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
            return selectedPlaceTypes.first ?? "All Places"
        } else {
            return "\(selectedPlaceTypes.count) Types"
        }
    }
} 