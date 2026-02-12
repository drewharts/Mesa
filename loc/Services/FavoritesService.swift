//
//  FavoritesService.swift
//  loc
//
//  Single Responsibility: Manages all favorites operations with proper validation.
//  This service encapsulates favorites business logic and provides a clean API.
//

import Foundation

// MARK: - Favorites Error Types

enum FavoritesError: LocalizedError {
    case alreadyFavorited
    case notFavorited
    case databaseError(underlying: Error)
    case userNotAuthenticated
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .alreadyFavorited:
            return "This place is already in your favorites."
        case .notFavorited:
            return "This place is not in your favorites."
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .userNotAuthenticated:
            return "You must be logged in to manage favorites."
        case .invalidResponse:
            return "Received an unexpected response from the server."
        }
    }
}

// MARK: - Favorites Result

enum AddFavoriteResult {
    case success
    case duplicate
    case error(Error)
}

// MARK: - Favorites Service

/// Single source of truth for favorites operations.
/// Follows SRP: Only handles favorites-related business logic.
@MainActor
class FavoritesService {
    
    // MARK: - Singleton
    static let shared = FavoritesService()
    
    // MARK: - Dependencies
    private let supabase: SupabaseManager
    
    // MARK: - Init
    private init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }
    
    // MARK: - Public API
    
    /// Safely adds a favorite with server-side validation.
    /// Uses database function for atomic check-and-insert.
    ///
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - placeId: The place to favorite
    /// - Returns: Result indicating success or specific failure reason
    func addFavorite(userId: String, placeId: String) async -> AddFavoriteResult {
        do {
            // Call the database function that handles atomic validation
            let response: String = try await supabase.client
                .rpc("add_favorite_safe", params: [
                    "p_user_id": userId,
                    "p_place_id": placeId
                ])
                .execute()
                .value
            
            switch response {
            case "success":
                print("✅ [FavoritesService] Successfully added favorite for place: \(placeId)")
                return .success
            case "duplicate":
                print("⚠️ [FavoritesService] Place already favorited: \(placeId)")
                return .duplicate
            default:
                print("❌ [FavoritesService] Unexpected response: \(response)")
                return .error(FavoritesError.invalidResponse)
            }
        } catch {
            print("❌ [FavoritesService] Error adding favorite: \(error)")
            return .error(error)
        }
    }
    
    /// Removes a favorite.
    ///
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - placeId: The place to unfavorite
    /// - Throws: FavoritesError if removal fails
    func removeFavorite(userId: String, placeId: String) async throws {
        do {
            try await supabase.client
                .from("favorites")
                .delete()
                .eq("user_id", value: userId)
                .eq("place_id", value: placeId)
                .execute()
            
            print("✅ [FavoritesService] Successfully removed favorite for place: \(placeId)")
        } catch {
            print("❌ [FavoritesService] Error removing favorite: \(error)")
            throw FavoritesError.databaseError(underlying: error)
        }
    }
    
    /// Checks if a place is favorited by a user.
    ///
    /// - Parameters:
    ///   - userId: The user's ID
    ///   - placeId: The place to check
    /// - Returns: True if the place is favorited
    func isFavorited(userId: String, placeId: String) async -> Bool {
        do {
            let count: Int = try await supabase.client
                .from("favorites")
                .select("*", head: true, count: .exact)
                .eq("user_id", value: userId)
                .eq("place_id", value: placeId)
                .execute()
                .count ?? 0
            
            return count > 0
        } catch {
            print("❌ [FavoritesService] Error checking favorite status: \(error)")
            return false
        }
    }
    
    /// Gets the current favorites count for a user.
    ///
    /// - Parameter userId: The user's ID
    /// - Returns: Number of favorites (0 if error)
    func getFavoritesCount(userId: String) async -> Int {
        do {
            let count: Int = try await supabase.client
                .from("favorites")
                .select("*", head: true, count: .exact)
                .eq("user_id", value: userId)
                .execute()
                .count ?? 0
            
            return count
        } catch {
            print("❌ [FavoritesService] Error getting favorites count: \(error)")
            return 0
        }
    }
    
    /// Fetches all favorites for a user.
    ///
    /// - Parameter userId: The user's ID
    /// - Returns: Array of FavoritePlace objects
    func fetchFavorites(userId: String) async throws -> [FavoritePlace] {
        struct Params: Encodable {
            let p_user_id: String
        }
        
        let params = Params(p_user_id: userId)
        
        let favorites: [FavoritePlace] = try await supabase.client
            .rpc("get_user_favorite_places", params: params)
            .execute()
            .value
        
        print("✅ [FavoritesService] Fetched \(favorites.count) favorites for user: \(userId)")
        return favorites
    }
}

