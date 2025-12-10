//
//  CustomPlaceCreatorViewModel.swift
//  loc
//
//  Smart component for managing custom place creator data.
//  Follows MVVM pattern - handles fetching and state management.
//

import Foundation
import Combine

/// ViewModel for fetching and displaying custom place creator information.
/// This is a "Smart Component" because it:
/// - Fetches data from a service
/// - Manages loading state
/// - Has business logic (determining when to fetch)
@MainActor
final class CustomPlaceCreatorViewModel: ObservableObject {
    
    // MARK: - Dependencies (Services only, per MVVM guidelines)
    
    private let placeService: PlaceService
    
    // MARK: - Published Properties (What the View Needs)
    
    @Published private(set) var creator: CustomPlaceCreator?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasLoaded: Bool = false
    
    // MARK: - Private State
    
    private var currentPlaceId: String?
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// Returns true if there's a creator to display
    var hasCreator: Bool {
        creator != nil
    }
    
    /// Creator's display name
    var creatorName: String? {
        creator?.fullName
    }
    
    /// Creator's user ID for navigation
    var creatorUserId: String? {
        creator?.userId
    }
    
    /// Creator's profile photo URL
    var creatorPhotoUrl: String? {
        creator?.profilePhotoUrl
    }
    
    // MARK: - Initialization
    
    init(placeService: PlaceService) {
        self.placeService = placeService
    }
    
    // MARK: - Public Methods
    
    /// Set the place to fetch creator for.
    /// Only fetches if the place is custom and we haven't already loaded for this place.
    func setPlace(_ place: DetailPlace?) {
        guard let place = place else {
            reset()
            return
        }
        
        // Only fetch for custom places
        guard place.isCustom == true else {
            reset()
            return
        }
        
        let placeId = place.id.uuidString
        
        // Skip if already loaded for this place
        guard currentPlaceId != placeId else {
            return
        }
        
        currentPlaceId = placeId
        fetchCreator(placeId: placeId)
    }
    
    // MARK: - Private Methods
    
    private func fetchCreator(placeId: String) {
        // Cancel any existing load task
        loadTask?.cancel()
        
        isLoading = true
        hasLoaded = false
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let fetchedCreator = try await self.placeService.fetchCustomPlaceCreator(placeId: placeId)
                
                // Ensure we haven't been cancelled or place changed
                guard !Task.isCancelled, self.currentPlaceId == placeId else {
                    return
                }
                
                self.creator = fetchedCreator
                self.isLoading = false
                self.hasLoaded = true
                
            } catch {
                // Only log if not cancelled
                if !Task.isCancelled {
                    print("❌ [CustomPlaceCreatorVM] Error fetching creator: \(error)")
                    self.creator = nil
                    self.isLoading = false
                    self.hasLoaded = true
                }
            }
        }
    }
    
    private func reset() {
        loadTask?.cancel()
        currentPlaceId = nil
        creator = nil
        isLoading = false
        hasLoaded = false
    }
}

