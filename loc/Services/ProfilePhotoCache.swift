//
//  ProfilePhotoCache.swift
//  loc
//
//  Created by Assistant on clean MVVM refactoring
//  Shared cache for user profile photos across the app
//

import SwiftUI

/// Shared cache for user profile photos
/// Single Responsibility: Manage profile photo loading and caching
@MainActor
class ProfilePhotoCache: ObservableObject {
    static let shared = ProfilePhotoCache()
    
    /// Cache of loaded profile photos
    @Published private(set) var photos: [String: UIImage] = [:]
    
    /// Track ongoing loading tasks to prevent duplicates
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    
    private init() {}
    
    /// Load a profile photo for a user
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - photoURL: The URL of the photo to load
    func loadPhoto(userId: String, photoURL: URL) async {
        // Prevent duplicate loads
        guard photos[userId] == nil, loadingTasks[userId] == nil else {
            return
        }
        
        let task = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: photoURL)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.photos[userId] = image
                    }
                    print("📸 [ProfilePhotoCache] Loaded photo for user: \(userId)")
                } else {
                    print("⚠️ [ProfilePhotoCache] Failed to create image from data for user: \(userId)")
                }
            } catch {
                print("⚠️ [ProfilePhotoCache] Failed to load photo for user \(userId): \(error.localizedDescription)")
            }
            
            // Clean up task reference
            await MainActor.run {
                self.loadingTasks[userId] = nil
            }
        }
        
        loadingTasks[userId] = task
        await task.value
    }
    
    /// Get a cached photo for a user
    /// - Parameter userId: The user's ID
    /// - Returns: The cached UIImage, or nil if not loaded
    func photo(for userId: String) -> UIImage? {
        return photos[userId]
    }
    
    /// Check if a photo is currently loading
    /// - Parameter userId: The user's ID
    /// - Returns: True if the photo is being loaded
    func isLoading(for userId: String) -> Bool {
        return loadingTasks[userId] != nil
    }
    
    /// Clear all cached photos (useful for memory management)
    func clearCache() {
        photos.removeAll()
        loadingTasks.values.forEach { $0.cancel() }
        loadingTasks.removeAll()
        print("🗑️ [ProfilePhotoCache] Cleared all cached photos")
    }
    
    /// Clear a specific user's photo from cache
    /// - Parameter userId: The user's ID
    func clearPhoto(for userId: String) {
        photos.removeValue(forKey: userId)
        loadingTasks[userId]?.cancel()
        loadingTasks.removeValue(forKey: userId)
    }
}

