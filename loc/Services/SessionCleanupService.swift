//
//  SessionCleanupService.swift
//  loc
//
//  Single Responsibility: Coordinates cleanup of all session-related caches on logout
//  This service centralizes cache clearing logic to prevent data leakage between user sessions.
//
//  Architecture Notes:
//  - Follows SRP: This service ONLY handles session cleanup coordination
//  - Follows DIP: Depends on abstractions (protocols) where possible
//  - Decouples UserSession from knowing about individual cache implementations
//

import Foundation

/// Protocol for any cache that needs clearing on logout
protocol SessionAwareCache {
    func clearForLogout()
}

/// Coordinates cleanup of all session-related caches
/// Single Responsibility: Orchestrate cache clearing on user logout
@MainActor
final class SessionCleanupService {
    
    // MARK: - Singleton
    static let shared = SessionCleanupService()
    
    // MARK: - Dependencies
    // Weak references to avoid retain cycles - ViewModels are owned by app lifecycle
    private weak var detailPlaceViewModel: DetailPlaceViewModel?
    private weak var selectedPlaceViewModel: SelectedPlaceViewModel?
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Configure with dependencies that aren't singletons
    /// Call this during app initialization
    func configure(
        detailPlaceViewModel: DetailPlaceViewModel,
        selectedPlaceViewModel: SelectedPlaceViewModel
    ) {
        self.detailPlaceViewModel = detailPlaceViewModel
        self.selectedPlaceViewModel = selectedPlaceViewModel
    }
    
    // MARK: - Public API
    
    /// Clears all session-related caches
    /// Call this on user logout to prevent data leakage between accounts
    func clearAllSessionData() {
        print("🔒 [SessionCleanupService] Clearing all session data for security...")
        
        clearViewModelCaches()
        clearImageCaches()
        clearMetadataCaches()
        
        print("✅ [SessionCleanupService] All session data cleared")
    }
    
    // MARK: - Private Methods
    
    private func clearViewModelCaches() {
        // Clear DetailPlaceViewModel's user-specific data (profile pictures, places, annotations)
        detailPlaceViewModel?.clearAllUserData()
        
        // Clear SelectedPlaceViewModel's cached posts and TikToks
        selectedPlaceViewModel?.clearAllUserData()
    }
    
    private func clearImageCaches() {
        // Clear all image-related caches (memory + disk)
        ImageCacheService.shared.clearAllCache()
        ProfilePhotoCache.shared.clearCache()
    }
    
    private func clearMetadataCaches() {
        // Clear TikTok metadata cache
        TikTokMetadataCache.shared.clearCache()
    }
}

