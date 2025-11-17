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
            
            print("✅ [PlaceListService] Fetched \(lists.count) lists (page \(page))")
            return lists
        } catch {
            print("❌ [PlaceListService] Error fetching lists: \(error)")
            throw error
        }
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
            
            return places
        } catch {
            print("❌ [PlaceListService] Error fetching places for list \(listId): \(error)")
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
            let user_id: String
            let name: String
            let city: String?
            let emoji: String?
            let image: String?
        }
        
        let newList = NewPlaceListRecord(
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
            print("✅ [PlaceListService] Created list: \(name)")
            return placeList
        } catch {
            print("❌ [PlaceListService] Error creating list: \(error)")
            throw error
        }
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

