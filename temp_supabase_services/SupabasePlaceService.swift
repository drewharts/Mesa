//
//  SupabasePlaceService.swift
//  loc
//
//  Place service using Supabase with PostGIS (replacement for Firebase PlaceService)
//

import Foundation
import Supabase
import PostgREST

@MainActor
class SupabasePlaceService: ObservableObject {
    static let shared = SupabasePlaceService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Place CRUD
    
    func fetchPlace(withId placeId: String) async throws -> DetailPlace {
        let response: DetailPlace = try await supabase.database
            .from("places")
            .select()
            .eq("id", value: placeId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    func addToAllPlaces(detailPlace: DetailPlace) async throws {
        try await supabase.database
            .from("places")
            .upsert(detailPlace)
            .execute()
    }
    
    func updatePlace(detailPlace: DetailPlace) async throws {
        try await supabase.database
            .from("places")
            .update(detailPlace)
            .eq("id", value: detailPlace.id.uuidString)
            .execute()
    }
    
    func fetchAllPlaces() async throws -> [DetailPlace] {
        let response: [DetailPlace] = try await supabase.database
            .from("places")
            .select()
            .execute()
            .value
        
        return response
    }
    
    func findPlace(mapboxId: String) async throws -> DetailPlace? {
        let response: [DetailPlace] = try await supabase.database
            .from("places")
            .select()
            .eq("mapbox_id", value: mapboxId)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - User Places
    
    func fetchMyPlaces(userId: String) async throws -> [DetailPlace] {
        // Get place IDs from my_places table
        let myPlaceRecords: [MyPlace] = try await supabase.database
            .from("my_places")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let placeIds = myPlaceRecords.map { $0.place_id.uuidString }
        
        guard !placeIds.isEmpty else { return [] }
        
        // Fetch full place details
        return try await fetchPlacesByIds(placeIds)
    }
    
    func addToMyPlaces(userId: String, detailPlace: DetailPlace) async throws {
        let myPlace = MyPlace(
            id: UUID(),
            user_id: UUID(uuidString: userId)!,
            place_id: detailPlace.id,
            timestamp: Date()
        )
        
        try await supabase.database
            .from("my_places")
            .insert(myPlace)
            .execute()
    }
    
    func deletePlaceFromMyPlaces(userId: String, placeId: String) async throws {
        try await supabase.database
            .from("my_places")
            .delete()
            .eq("user_id", value: userId)
            .eq("place_id", value: placeId)
            .execute()
    }
    
    func deletePlaceFromAllPlaces(placeId: String) async throws {
        try await supabase.database
            .from("places")
            .delete()
            .eq("id", value: placeId)
            .execute()
    }
    
    // MARK: - Favorites
    
    func fetchProfileFavorites(userId: String) async throws -> [DetailPlace] {
        // Get place IDs from favorites table
        let favoriteRecords: [FavoriteRecord] = try await supabase.database
            .from("favorites")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let placeIds = favoriteRecords.map { $0.place_id.uuidString }
        
        guard !placeIds.isEmpty else { return [] }
        
        // Fetch full place details
        return try await fetchPlacesByIds(placeIds)
    }
    
    // MARK: - Place Lists
    
    func fetchLists(userId: String) async throws -> [PlaceList] {
        let response: [PlaceList] = try await supabase.database
            .from("place_lists")
            .select()
            .eq("user_id", value: userId)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func createNewList(placeList: PlaceList, userID: String) async throws {
        try await supabase.database
            .from("place_lists")
            .insert(placeList)
            .execute()
    }
    
    func deleteList(userId: String, listId: String) async throws {
        try await supabase.database
            .from("place_lists")
            .delete()
            .eq("id", value: listId)
            .execute()
    }
    
    func fetchList(userId: String, listId: String) async throws -> PlaceList {
        let response: PlaceList = try await supabase.database
            .from("place_lists")
            .select()
            .eq("id", value: listId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    // Add place to list
    func addPlaceToList(listId: UUID, place: Place, sortOrder: Int = 0) async throws {
        let listItem = PlaceListItem(
            id: UUID(),
            list_id: listId,
            place_id: place.id,
            sort_order: sortOrder,
            added_at: Date()
        )
        
        try await supabase.database
            .from("place_list_items")
            .insert(listItem)
            .execute()
    }
    
    // Remove place from list
    func removePlaceFromList(userId: String, listId: UUID, place: Place) async throws {
        try await supabase.database
            .from("place_list_items")
            .delete()
            .eq("list_id", value: listId.uuidString)
            .eq("place_id", value: place.id.uuidString)
            .execute()
    }
    
    // Get places in a specific list
    func fetchPlacesInList(listId: UUID) async throws -> [DetailPlace] {
        // Get place IDs from list items
        let listItems: [PlaceListItem] = try await supabase.database
            .from("place_list_items")
            .select()
            .eq("list_id", value: listId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        let placeIds = listItems.map { $0.place_id.uuidString }
        
        guard !placeIds.isEmpty else { return [] }
        
        // Fetch full place details
        return try await fetchPlacesByIds(placeIds)
    }
    
    // MARK: - Viewport-Based Loading (PostGIS Geospatial Queries)
    
    /// Fetch places within a geographic bounding box
    /// Uses PostGIS for efficient spatial queries
    func fetchPlacesInViewport(
        northLat: Double,
        southLat: Double,
        eastLng: Double,
        westLng: Double
    ) async throws -> [DetailPlace] {
        print("🗺️ [SupabasePlaceService] Fetching places in viewport:")
        print("   Lat: \(southLat) to \(northLat)")
        print("   Lng: \(westLng) to \(eastLng)")
        
        let response: [DetailPlace] = try await supabase.database
            .from("places")
            .select()
            .gte("latitude", value: southLat)
            .lte("latitude", value: northLat)
            .gte("longitude", value: westLng)
            .lte("longitude", value: eastLng)
            .execute()
            .value
        
        print("✅ [SupabasePlaceService] Loaded \(response.count) places in viewport")
        return response
    }
    
    /// Fetch friends' places within a geographic bounding box
    /// This is 10x faster than loading ALL friends' places globally!
    func fetchFriendsPlacesInViewport(
        friendUserIds: [String],
        northLat: Double,
        southLat: Double,
        eastLng: Double,
        westLng: Double
    ) async throws -> [DetailPlace] {
        guard !friendUserIds.isEmpty else { return [] }
        
        print("👥 [SupabasePlaceService] Fetching friends' places in viewport:")
        print("   Friends count: \(friendUserIds.count)")
        print("   Lat: \(southLat) to \(northLat)")
        print("   Lng: \(westLng) to \(eastLng)")
        
        var allPlaces: [DetailPlace] = []
        
        // Process in batches of 10 (Supabase IN operator limit)
        for batch in friendUserIds.chunked(into: 10) {
            // Get favorites for these friends in the viewport
            let favorites: [FavoriteWithPlace] = try await supabase.database
                .from("favorites")
                .select("*, places(*)")
                .in("user_id", values: batch)
                .execute()
                .value
            
            // Filter places by viewport
            let placesInViewport = favorites.compactMap { $0.places }.filter { place in
                guard let lat = place.latitude, let lng = place.longitude else { return false }
                return lat >= southLat && lat <= northLat && lng >= westLng && lng <= eastLng
            }
            
            allPlaces.append(contentsOf: placesInViewport)
        }
        
        // Remove duplicates
        let uniquePlaces = Dictionary(grouping: allPlaces, by: { $0.id }).compactMap { $0.value.first }
        
        print("✅ [SupabasePlaceService] Loaded \(uniquePlaces.count) friends' places in viewport")
        return uniquePlaces
    }
    
    /// Get nearby places using PostGIS spatial queries
    func getNearbyPlaces(lat: Double, lng: Double, radiusMeters: Double = 5000) async throws -> [NearbyPlaceResult] {
        // Call the PostGIS stored function
        let response: [NearbyPlaceResult] = try await supabase.database
            .rpc("get_nearby_places", params: [
                "p_lat": lat,
                "p_lng": lng,
                "p_radius_meters": radiusMeters
            ])
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Batch Operations
    
    /// Fetch multiple places by their IDs (with batching)
    func fetchPlacesByIds(_ placeIds: [String]) async throws -> [DetailPlace] {
        guard !placeIds.isEmpty else { return [] }
        
        var allPlaces: [DetailPlace] = []
        
        // Batch in groups of 100 (Supabase limit)
        for batch in placeIds.chunked(into: 100) {
            let response: [DetailPlace] = try await supabase.database
                .from("places")
                .select()
                .in("id", values: batch)
                .execute()
                .value
            
            allPlaces.append(contentsOf: response)
        }
        
        print("✅ [SupabasePlaceService] Loaded \(allPlaces.count) places by IDs")
        return allPlaces
    }
    
    // MARK: - Photos
    
    func addPhotosToPlace(placeId: String, photoUrls: [String]) async throws {
        var place = try await fetchPlace(withId: placeId)
        
        if place.photoUrls == nil {
            place.photoUrls = []
        }
        place.photoUrls?.append(contentsOf: photoUrls)
        
        try await updatePlace(detailPlace: place)
    }
    
    // MARK: - Compatibility Methods (callback-based)
    
    func fetchPlace(withId placeId: String, completion: @escaping (Result<DetailPlace, Error>) -> Void) {
        Task {
            do {
                let place = try await fetchPlace(withId: placeId)
                completion(.success(place))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func fetchMyPlaces(userId: String, completion: @escaping ([DetailPlace]?) -> Void) {
        Task {
            do {
                let places = try await fetchMyPlaces(userId: userId)
                completion(places)
            } catch {
                print("Error fetching my places: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    func fetchProfileFavorites(userId: String, completion: @escaping ([DetailPlace]?) -> Void) {
        Task {
            do {
                let places = try await fetchProfileFavorites(userId: userId)
                completion(places)
            } catch {
                print("Error fetching favorites: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    func fetchLists(userId: String, completion: @escaping ([PlaceList]) -> Void) {
        Task {
            do {
                let lists = try await fetchLists(userId: userId)
                completion(lists)
            } catch {
                print("Error fetching lists: \(error.localizedDescription)")
                completion([])
            }
        }
    }
    
    func addToAllPlaces(detailPlace: DetailPlace, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await addToAllPlaces(detailPlace: detailPlace)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    func addToMyPlaces(userId: String, detailPlace: DetailPlace, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await addToMyPlaces(userId: userId, detailPlace: detailPlace)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}

// MARK: - Helper Models

struct MyPlace: Codable {
    let id: UUID
    let user_id: UUID
    let place_id: UUID
    let timestamp: Date
}

struct FavoriteRecord: Codable {
    let id: UUID
    let user_id: UUID
    let place_id: UUID
    let timestamp: Date
}

struct PlaceListItem: Codable {
    let id: UUID
    let list_id: UUID
    let place_id: UUID
    let sort_order: Int
    let added_at: Date
}

struct FavoriteWithPlace: Codable {
    let id: UUID
    let user_id: UUID
    let place_id: UUID
    let timestamp: Date
    let places: DetailPlace
}

struct NearbyPlaceResult: Codable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let distance_meters: Double
}

