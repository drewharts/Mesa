//
//  PlaceSaversViewModel.swift
//  loc
//
//  Smart ViewModel for managing place savers data and navigation
//  Follows Single Responsibility: owns all business logic for "who saved this place"
//
//  Data Flow:
//  1. setPlace() is called when PlaceDetailView appears
//  2. Fetches savers from database in real-time (not relying on pre-loaded data)
//  3. Updates placeSavers dictionary in DetailPlaceViewModel for consistency
//  4. UI reacts to @Published property changes
//

import Foundation
import UIKit
import Combine

@MainActor
class PlaceSaversViewModel: ObservableObject {
    // MARK: - Published Properties (What the View Needs)
    @Published private(set) var savers: [ProfileData] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    @Published private(set) var currentUserSaved: Bool = false
    @Published private(set) var totalSaverCount: Int = 0  // Count of visible savers (profiles you can see)
    @Published private(set) var totalGlobalSaveCount: Int = 0  // Total saves from ALL users (for display)
    
    // MARK: - Dependencies (Services, not other ViewModels)
    private let userService: UserService
    private let detailPlaceViewModel: DetailPlaceViewModel
    private let userSession: UserSession
    
    // For user navigation (temporary coupling during migration)
    private weak var userProfileViewModel: UserProfileViewModel?
    
    private var cancellables = Set<AnyCancellable>()
    private var currentPlaceId: String?
    private var fetchTask: Task<Void, Never>?
    
    // MARK: - Initialization
    init(userService: UserService,
         detailPlaceViewModel: DetailPlaceViewModel,
         userSession: UserSession) {
        self.userService = userService
        self.detailPlaceViewModel = detailPlaceViewModel
        self.userSession = userSession
    }
    
    // MARK: - Configuration
    
    /// Call this to set up the UserProfileViewModel reference for navigation
    func configure(userProfileViewModel: UserProfileViewModel) {
        self.userProfileViewModel = userProfileViewModel
    }
    
    // MARK: - Public Actions
    
    /// Updates the current place and fetches savers in real-time
    func setPlace(_ placeId: String?) {
        // Cancel any in-flight fetch
        fetchTask?.cancel()
        
        currentPlaceId = placeId
        guard let placeId = placeId else {
            resetState()
            return
        }
        
        print("🔍 [PlaceSavers] setPlace called for: \(placeId.prefix(8))...")
        
        // Fetch savers from database in real-time
        fetchSaversFromDatabase(placeId: placeId)
    }
    
    /// Handles user tap - navigates to their profile
    /// Takes dismiss closure from View (View owns presentation state)
    func selectUser(_ user: ProfileData, dismiss: @escaping () -> Void) {
        guard let currentUserId = userSession.currentUserId,
              let userProfileVM = userProfileViewModel else { return }
        
        // Dismiss sheet first (View handles this)
        dismiss()
        
        // Navigate after brief delay for smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            userProfileVM.selectUser(user, currentUserId: currentUserId)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Savers excluding current user (for indicator and sheet list)
    /// Rationale: "Saved by" is about social discovery - you already know you saved it
    var displayableSavers: [ProfileData] {
        guard let currentUserId = userSession.currentUserId else { return savers }
        return savers.filter { $0.id != currentUserId }
    }
    
    /// Count of savers excluding current user (for indicator)
    var displayableSaverCount: Int {
        displayableSavers.count
    }
    
    /// Number of additional savers beyond visible circles (for "+X" display)
    /// Excludes current user - only shows count of OTHER savers
    var additionalSaverCount: Int {
        max(0, displayableSaverCount - 3)
    }
    
    /// Whether to show the savers indicator at all
    /// Only show if OTHER people (not just you) have saved this place
    var shouldShowSaversIndicator: Bool {
        displayableSaverCount > 0
    }
    
    /// Get first N saver IDs for profile circle display (excluding current user)
    func saverIdsForDisplay(limit: Int = 3) -> [String] {
        return Array(displayableSavers.prefix(limit).map { $0.id })
    }
    
    /// Get first N savers (ProfileData) for profile circle display (excluding current user)
    /// Shows only OTHER people who saved this place - you don't need to see your own face
    func saversForDisplay(limit: Int = 3) -> [ProfileData] {
        return Array(displayableSavers.prefix(limit))
    }
    
    // MARK: - Private Methods
    
    /// Fetches place savers from database in real-time
    private func fetchSaversFromDatabase(placeId: String) {
        fetchTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Don't show loading for quick fetches (better UX)
            // isLoading = true
            
            do {
                let requestingUserId = self.userSession.currentUserId
                
                // Fetch savers and total count in parallel
                async let saverProfilesTask = self.userService.fetchPlaceSavers(
                    placeId: placeId,
                    requestingUserId: requestingUserId
                )
                async let totalCountTask = SupabasePlaceService.shared.fetchTotalSaveCount(for: placeId)
                
                let (saverProfiles, globalCount) = try await (saverProfilesTask, totalCountTask)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Update state
                self.savers = saverProfiles.map { $0.toProfileData() }
                self.totalSaverCount = saverProfiles.count
                self.totalGlobalSaveCount = globalCount
                
                // Check if current user is in the savers list
                if let currentUserId = requestingUserId {
                    self.currentUserSaved = saverProfiles.contains { $0.userId == currentUserId }
                } else {
                    self.currentUserSaved = false
                }
                
                // Update detailPlaceViewModel.placeSavers for consistency with map annotations
                let saverIds = saverProfiles.map { $0.userId }
                if !saverIds.isEmpty {
                    self.detailPlaceViewModel.placeSavers[placeId] = saverIds
                }
                
                self.error = nil
                self.isLoading = false
                
                print("✅ [PlaceSavers] Fetched \(saverProfiles.count) visible savers, \(globalCount) total saves for place \(placeId.prefix(8))...")
                
            } catch {
                guard !Task.isCancelled else { return }
                
                print("❌ [PlaceSavers] Error fetching savers: \(error.localizedDescription)")
                self.error = error
                self.isLoading = false
                self.totalSaverCount = 0
                self.totalGlobalSaveCount = 0
                self.savers = []
            }
        }
    }
    
    private func resetState() {
        savers = []
        isLoading = false
        error = nil
        currentUserSaved = false
        totalSaverCount = 0
        totalGlobalSaveCount = 0
    }
}

