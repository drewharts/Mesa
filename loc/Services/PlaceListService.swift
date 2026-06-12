//
//  PlaceListService.swift
//  loc
//
//  Service responsible for ALL place list operations
//  Single source of truth for place list data access
//

import Foundation
import CoreLocation

/// Service for managing place lists (fetch, create, update, delete)
/// Owns all database operations related to place lists
@MainActor
class PlaceListService {
    // MARK: - Singleton
    static let shared = PlaceListService()
    
    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Fetch Place Lists
    
    /// Fetch user's place lists sorted by proximity to a location
    /// Returns lightweight list data with pagination support
    func fetchListsByProximity(
        userId: String,
        latitude: Double,
        longitude: Double,
        page: Int = 1,
        pageSize: Int = 6
    ) async throws -> [LightweightPlaceList] {
        struct Params: Encodable {
            let p_user_id: String
            let p_user_location: String // PostGIS geometry as WKT
            let p_page: Int
            let p_page_size: Int
        }
        
        // Convert lat/lng to PostGIS POINT geometry in EWKT format with SRID
        let userLocation = "SRID=4326;POINT(\(longitude) \(latitude))"
        
        let params = Params(
            p_user_id: userId,
            p_user_location: userLocation,
            p_page: page,
            p_page_size: pageSize
        )
        
        do {
            let lists: [LightweightPlaceList] = try await supabase.client
                .rpc("get_paginated_user_place_lists_by_proximity", params: params)
                .execute()
                .value
            
            return lists
        } catch {
            print("❌ [PlaceListService] Error fetching lists: \(error)")
            throw error
        }
    }
    
    /// Search user's place lists by name with server-side filtering
    /// Returns all matching lists regardless of pagination for comprehensive search results
    func searchListsByName(
        userId: String,
        searchTerm: String,
        limit: Int = 50
    ) async throws -> [LightweightPlaceList] {
        struct Params: Encodable {
            let p_user_id: String
            let p_search_term: String
            let p_limit: Int
        }
        
        let params = Params(
            p_user_id: userId,
            p_search_term: searchTerm,
            p_limit: limit
        )
        
        let lists: [LightweightPlaceList] = try await supabase.client
            .rpc("search_user_place_lists", params: params)
            .execute()
            .value
        
        return lists
    }
    
    // MARK: - All List Metadata

    /// Fetches lightweight metadata for all lists owned by a user (for instant local search).
    func fetchAllListMetadata(userId: String) async throws -> [LightweightPlaceList] {
        struct Params: Encodable {
            let p_user_id: String
        }

        let lists: [LightweightPlaceList] = try await supabase.client
            .rpc("get_all_user_list_metadata", params: Params(p_user_id: userId))
            .execute()
            .value

        return lists
    }

    // MARK: - Fetch Places in List
    
    /// Fetch places within a specific place list with pagination
    /// Used to check if a place is already in a list (for checkmarks)
    func fetchPlacesInList(
        listId: String,
        page: Int = 1,
        pageSize: Int = 6
    ) async throws -> [LightweightPlace] {
        struct Params: Encodable {
            let p_list_id: String
            let p_page: Int
            let p_page_size: Int
        }
        
        let params = Params(
            p_list_id: listId,
            p_page: page,
            p_page_size: pageSize
        )
        
        do {
            let places: [LightweightPlace] = try await supabase.client
                .rpc("get_paginated_place_list_places", params: params)
                .execute()
                .value

            // Deduplicate by place_id — the SQL LEFT JOIN with external_places
            // can return multiple rows per place when a user has multiple external entries.
            // Duplicate IDs cause invisible cells in SwiftUI ForEach/LazyVGrid.
            var seen = Set<String>()
            return places.filter { seen.insert($0.place_id).inserted }
        } catch {
            print("❌ [PlaceListService] Error fetching places for list \(listId): \(error)")
            throw error
        }
    }
    
    /// Check if a specific place is in a specific list
    /// This is more efficient than fetching all places when we just need to check membership
    func isPlaceInList(listId: String, placeId: String) async throws -> Bool {
        struct PlaceListItemCheck: Decodable {
            let place_id: String
        }
        
        do {
            let response = try await supabase.client
                .from("place_list_items")
                .select("place_id")
                .eq("list_id", value: listId)
                .eq("place_id", value: placeId)
                .limit(1)
                .execute()
            
            let items = try JSONDecoder().decode([PlaceListItemCheck].self, from: response.data)
            return !items.isEmpty
        } catch {
            print("❌ [PlaceListService] Error checking if place is in list: \(error)")
            throw error
        }
    }
    
    /// Check if a place is in ANY of the user's lists (database function)
    /// Used for bookmark icon state in place detail view
    func isPlaceInAnyUserList(userId: String, placeId: String) async throws -> Bool {
        struct BoolResult: Decodable {
            let is_place_in_user_lists: Bool
        }
        
        do {
            let result: Bool = try await supabase.client
                .rpc("is_place_in_user_lists", params: [
                    "p_user_id": userId,
                    "p_place_id": placeId
                ])
                .execute()
                .value
            
            return result
        } catch {
            print("❌ [PlaceListService] Error checking if place is in any user list: \(error)")
            throw error
        }
    }
    
    // MARK: - Create Place List
    
    /// Create a new place list for a user
    func createList(
        userId: String,
        name: String,
        city: String = "",
        emoji: String = "",
        image: String = ""
    ) async throws -> PlaceList {
        struct NewPlaceListRecord: Encodable {
            let id: String
            let user_id: String
            let name: String
            let city: String?
            let emoji: String?
            let image: String?
        }
        
        // Generate UUID client-side for reliability (doesn't depend on DB defaults)
        let listId = UUID()
        
        let newList = NewPlaceListRecord(
            id: listId.uuidString,
            user_id: userId,
            name: name,
            city: city.isEmpty ? nil : city,
            emoji: emoji.isEmpty ? nil : emoji,
            image: image.isEmpty ? nil : image
        )
        
        do {
            let record: PlaceListRecord = try await supabase.client
                .from("place_lists")
                .insert(newList)
                .select()
                .single()
                .execute()
                .value
            
            let placeList = convertToPlaceList(record)
            return placeList
        } catch {
            throw error
        }
    }
    
    // MARK: - Delete Place List

    /// Deletes a place list and all its associated items from the database
    func deleteList(listId: String) async throws {
        try await supabase.client
            .from("place_lists")
            .delete()
            .eq("id", value: listId)
            .execute()
    }

    // MARK: - Update List Properties

    /// Updates the name of a place list.
    func updateListName(listId: String, name: String) async throws {
        struct UpdateData: Encodable {
            let name: String
        }

        try await supabase.client
            .from("place_lists")
            .update(UpdateData(name: name))
            .eq("id", value: listId)
            .execute()
    }

    /// Updates the description of a place list.
    func updateListDescription(listId: String, description: String?) async throws {
        struct UpdateData: Encodable {
            let description: String?
        }

        try await supabase.client
            .from("place_lists")
            .update(UpdateData(description: description))
            .eq("id", value: listId)
            .execute()
    }

    /// Updates the price tier for a place list (nil = free)
    func updateListPricing(listId: String, priceTier: String?) async throws {
        struct UpdateData: Encodable {
            let price_tier: String?
        }

        try await supabase.client
            .from("place_lists")
            .update(UpdateData(price_tier: priceTier))
            .eq("id", value: listId)
            .execute()
    }

    /// Updates the privacy setting for a place list.
    func updateListPrivacy(listId: String, isPublic: Bool) async throws {
        struct UpdateData: Encodable {
            let is_public: Bool
        }

        try await supabase.client
            .from("place_lists")
            .update(UpdateData(is_public: isPublic))
            .eq("id", value: listId)
            .execute()
    }
    
    // MARK: - Private Helpers
    
    private func convertToPlaceList(_ record: PlaceListRecord) -> PlaceList {
        // Parse the average location from WKT format if available
        let averageCoordinate = parseGeometryToCoordinate(record.average_location)
        
        return PlaceList(
            id: record.id,
            name: record.name,
            places: [], // Not loaded here
            city: record.city ?? "",
            emoji: record.emoji ?? "",
            image: record.image,
            sortOrder: 0,
            averageCoordinate: averageCoordinate,
            lastCoordinateUpdate: Date()
        )
    }
    
    private func parseGeometryToCoordinate(_ wkt: String?) -> CLLocationCoordinate2D? {
        guard let wkt = wkt else { return nil }
        
        // Parse WKT format: "POINT(longitude latitude)"
        let pattern = "POINT\\(([-.0-9]+)\\s+([-.0-9]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: wkt, range: NSRange(wkt.startIndex..., in: wkt)),
              match.numberOfRanges == 3 else {
            return nil
        }
        
        guard let lonRange = Range(match.range(at: 1), in: wkt),
              let latRange = Range(match.range(at: 2), in: wkt),
              let longitude = Double(wkt[lonRange]),
              let latitude = Double(wkt[latRange]) else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Supporting Types

private struct PlaceListRecord: Decodable {
    let id: UUID
    let user_id: String
    let name: String
    let city: String?
    let emoji: String?
    let image: String?
    let average_location: String?
    let created_at: String
    let updated_at: String
}

