//
//  PlacesCountViewModel.swift
//  loc
//
//  SMART Component: Manages fetching and state for user's total places count
//  Single Responsibility: Fetch and cache total places count for a user
//
//  Uses database function get_user_total_places_count which returns
//  the count of unique places a user has saved, reviewed, or created.
//

import Foundation
import Combine

@MainActor
final class PlacesCountViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var totalPlacesCount: Int = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var hasLoaded: Bool = false
    
    // MARK: - Dependencies
    
    private let userService: UserService
    
    // MARK: - Private State
    
    private var currentUserId: String?
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Cache
    // Cache counts per user to avoid redundant fetches
    private var countCache: [String: Int] = [:]
    
    // MARK: - Initialization
    
    init(userService: UserService) {
        self.userService = userService
    }
    
    // MARK: - Public Methods
    
    /// Fetch places count for a user
    /// - Parameter userId: The user ID to fetch count for
    func fetchCount(for userId: String) {
        // Return cached value if available
        if let cachedCount = countCache[userId] {
            self.totalPlacesCount = cachedCount
            self.hasLoaded = true
            return
        }
        
        // Skip if already loading for this user
        guard currentUserId != userId || !isLoading else { return }
        
        currentUserId = userId
        loadTask?.cancel()
        
        isLoading = true
        hasLoaded = false
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let count = try await self.userService.getTotalPlacesCount(forUserId: userId)
                
                guard !Task.isCancelled, self.currentUserId == userId else { return }
                
                self.totalPlacesCount = count
                self.countCache[userId] = count
                self.isLoading = false
                self.hasLoaded = true
                
            } catch {
                guard !Task.isCancelled else { return }
                
                print("❌ [PlacesCountVM] Error fetching count: \(error)")
                self.totalPlacesCount = 0
                self.isLoading = false
                self.hasLoaded = true
            }
        }
    }
    
    /// Clear cached count for a user (call after user adds/removes places)
    func invalidateCache(for userId: String) {
        countCache.removeValue(forKey: userId)
    }
    
    /// Clear all cached counts
    func clearAllCache() {
        countCache.removeAll()
    }
    
    /// Reset state (e.g., when navigating away)
    func reset() {
        loadTask?.cancel()
        currentUserId = nil
        totalPlacesCount = 0
        isLoading = false
        hasLoaded = false
    }
}


