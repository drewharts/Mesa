//
//  SupabasePlaceService.swift
//  loc
//
//  Place service using Supabase (replacement for Firebase PlaceService)
//

import Foundation
import Supabase
import CoreLocation

@MainActor
class SupabasePlaceService: ObservableObject {
    static let shared = SupabasePlaceService()
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Helper Functions
    
    /// Converts DetailPlace to PlaceRecord for Supabase insertion
    private func convertToPlaceRecord(_ place: DetailPlace) -> PlaceRecord {
        // Convert coordinate to PostGIS geometry string
        var locationString: String? = nil
        if let coordinate = place.coordinate {
            locationString = "POINT(\(coordinate.longitude) \(coordinate.latitude))"
        }
        
        return PlaceRecord(
            id: place.id.uuidString,
            name: place.name,
            address: place.address,
            city: place.city,
            description: place.description,
            location: locationString,
            geohash: nil, // Will be calculated by database trigger
            rating: place.rating,
            rating_count: place.userRatingsTotal,
            price_level: place.priceLevel,
            categories: place.categories,
            phone: place.phone,
            website: nil, // Not in DetailPlace model
            menu_url: nil, // Not in DetailPlace model
            instagram: place.Instagram,
            twitter: place.X,
            google_places_id: place.googlePlaceId,
            mapbox_id: place.mapboxId,
            fid: nil, // Not in DetailPlace model
            cid: nil, // Not in DetailPlace model
            thumbnail_url: place.photoUrls?.first,
            photo_urls: place.photoUrls,
            open_hours: place.openHours?.map { ["day": "Unknown", "hours": $0] }, // Convert to JSONB format
            reservable: place.reservable,
            serves_breakfast: place.servesBreakfast,
            serves_lunch: place.serversLunch,
            serves_dinner: place.serversDinner,
            source: place.source ?? "custom",
            updated_at: ISO8601DateFormatter().string(from: Date()),
            is_custom: place.isCustom ?? true // Default to true for custom places
        )
    }
    
    /// Parses PostGIS geometry string (WKT format) to CLLocationCoordinate2D
    private func parseGeometryToCoordinate(_ geometryString: String?) -> CLLocationCoordinate2D? {
        guard let geometryString = geometryString else { return nil }
        
        // Parse WKT format: "POINT(longitude latitude)"
        let pattern = #"POINT\(([-\d.]+)\s+([-\d.]+)\)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: geometryString.utf16.count)
        
        if let match = regex?.firstMatch(in: geometryString, range: range),
           let longitudeRange = Range(match.range(at: 1), in: geometryString),
           let latitudeRange = Range(match.range(at: 2), in: geometryString),
           let longitude = Double(String(geometryString[longitudeRange])),
           let latitude = Double(String(geometryString[latitudeRange])) {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        return nil
    }

    // MARK: - PlaceList Records

    struct PlaceListRecord: Codable {
        let id: String
        let user_id: String
        let name: String
        let description: String?
        let cover_image_url: String?
        let is_public: Bool
        let sort_order: Int
        let average_location: String? // PostGIS geometry as WKT string
        let distance_meters: Double? // Distance from user location (when sorted by proximity)

        enum CodingKeys: String, CodingKey {
            case id
            case user_id
            case name
            case description
            case cover_image_url
            case is_public
            case sort_order
            case average_location
            case distance_meters
        }
    }
    
    // MARK: - Fetch Places (matching Firebase PlaceService interface)
    
    func fetchAllPlaces() async throws -> [DetailPlace] {
        return try await withCheckedThrowingContinuation { continuation in
            fetchAllPlaces { places, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: places ?? [])
            }
        }
    }
    
    func fetchAllPlaces(completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        Task {
            do {
                print("📍 [Supabase] Fetching all places...")
                
                let response: [PlaceRecord] = try await supabase.client
                    .from("places")
                    .select()
                    .execute()
                    .value
                
                let places = response.map { convertToDetailPlace($0) }
                print("✅ [Supabase] Fetched \(places.count) places")
                completion(places, nil)
            } catch {
                print("❌ [Supabase] Error fetching places: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func findPlace(mapboxId: String, completion: @escaping (DetailPlace?, Error?) -> Void) {
        Task {
            do {
                let response: PlaceRecord = try await supabase.client
                    .from("places")
                    .select()
                    .eq("mapbox_id", value: mapboxId)
                    .single()
                    .execute()
                    .value
                
                let place = convertToDetailPlace(response)
                completion(place, nil)
            } catch {
                print("❌ [Supabase] Error finding place with mapboxId \(mapboxId): \(error)")
                completion(nil, error)
            }
        }
    }
    
    func fetchPlace(withId placeId: String, completion: @escaping (Result<DetailPlace, Error>) -> Void) {
        Task {
            do {
                let response: PlaceRecord = try await supabase.client
                    .from("places")
                    .select()
                    .eq("id", value: placeId)
                    .single()
                    .execute()
                    .value
                
                let place = convertToDetailPlace(response)
                completion(.success(place))
            } catch {
                print("❌ [Supabase] Error fetching place \(placeId): \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Favorites
    
    func fetchProfileFavorites(userId: String, completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        Task {
            do {
                print("🔍 [Supabase] Fetching profile favorites for user: \(userId)")
                
                // First get favorite place IDs
                let favoriteRecords: [FavoriteRecord] = try await supabase.client
                    .from("favorites")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                    .value
                
                print("🔍 [Supabase] Found \(favoriteRecords.count) favorite records")
                
                let placeIds = favoriteRecords.map { $0.place_id }
                
                guard !placeIds.isEmpty else {
                    print("🔍 [Supabase] No favorite place IDs found")
                    completion([], nil)
                    return
                }
                
                print("🔍 [Supabase] Fetching details for \(placeIds.count) favorite places")
                
                // Then fetch the places
                let response: [PlaceRecord] = try await supabase.client
                    .from("places")
                    .select()
                    .in("id", values: placeIds)
                    .execute()
                    .value
                
                let places = response.map { convertToDetailPlace($0) }
                print("✅ [Supabase] Successfully fetched \(places.count) favorite places")
                
                completion(places, nil)
            } catch {
                print("❌ [Supabase] Error fetching profile favorites: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func fetchProfileFavorites(userId: String) async throws -> [DetailPlace] {
        print("🔍 [Supabase] Fetching profile favorites async for user: \(userId)")
        
        // First get favorite place IDs
        let favoriteRecords: [FavoriteRecord] = try await supabase.client
            .from("favorites")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let placeIds = favoriteRecords.map { $0.place_id }
        
        guard !placeIds.isEmpty else {
            return []
        }
        
        let response: [PlaceRecord]
        do {
            response = try await supabase.client
                .from("places")
                .select()
                .in("id", values: placeIds)
                .execute()
                .value
            
            // Successfully fetched place records
        } catch {
            print("❌ [Supabase] Error fetching place records: \(error)")
            print("❌ [Supabase] Error type: \(type(of: error))")
            if let decodingError = error as? DecodingError {
                print("❌ [Supabase] Decoding error details: \(decodingError)")
            }
            throw error
        }
        
        var places: [DetailPlace] = []
        for (index, record) in response.enumerated() {
            do {
                let place = convertToDetailPlace(record)
                places.append(place)
            } catch {
                print("❌ [Supabase] Error converting place \(index + 1) (\(record.name)): \(error)")
                print("❌ [Supabase] Place record data: \(record)")
            }
        }
        
        print("✅ [Supabase] Successfully fetched \(places.count) favorite places")
        
        return places
    }
    
    func fetchFavorites(userId: String, completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        Task {
            do {
                // First get favorite place IDs
                let favoriteRecords: [FavoriteRecord] = try await supabase.client
                    .from("favorites")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                    .value
                
                let placeIds = favoriteRecords.map { $0.place_id }
                
                guard !placeIds.isEmpty else {
                    completion([], nil)
                    return
                }
                
                // Then fetch the places
                let response: [PlaceRecord] = try await supabase.client
                    .from("places")
                    .select()
                    .in("id", values: placeIds)
                    .execute()
                    .value
                
                let places = response.map { convertToDetailPlace($0) }
                completion(places, nil)
            } catch {
                print("❌ [Supabase] Error fetching favorites: \(error)")
                completion(nil, error)
            }
        }
    }
    
    // MARK: - All User Places (Optimized Single Query)
    
    /// Fetch ALL places saved by user from any source (my_places, favorites, place_lists)
    /// This is the fastest way to load all user's places - single database query!
    func fetchAllUserPlaces(userId: String) async throws -> [DetailPlace] {
        let startTime = Date()
        print("🚀 [Supabase] Fetching ALL user places with optimized query...")
        
        do {
            // Try using the optimized SQL function first
            let response: [PlaceRecord] = try await supabase.client
                .rpc("get_all_user_places", params: ["p_user_id": userId])
                .execute()
                .value
            
            let places = response.map { convertToDetailPlace($0) }
            let duration = Date().timeIntervalSince(startTime)
            
            print("✅ [Supabase] Fetched \(places.count) total places in \(String(format: "%.2f", duration))s (via RPC)")
            
            return places
        } catch {
            // Fallback: If RPC function doesn't exist, aggregate manually
            print("⚠️ [Supabase] RPC function not found, using fallback query: \(error)")
            return try await fetchAllUserPlacesFallback(userId: userId, startTime: startTime)
        }
    }
    
    /// Fallback method if RPC function doesn't exist
    /// Loads ALL places from my_places, favorites, AND all place_list_items
    private func fetchAllUserPlacesFallback(userId: String, startTime: Date) async throws -> [DetailPlace] {
        print("🔄 [Supabase] Using fallback to load ALL user places...")
        
        // Step 1: Get all unique place IDs from all sources
        var allPlaceIds = Set<String>()
        
        // Get from my_places
        do {
            let myPlacesRecords: [MyPlaceRecord] = try await supabase.client
                .from("my_places")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let myPlaceIds = myPlacesRecords.map { $0.place_id }
            allPlaceIds.formUnion(myPlaceIds)
            print("🔍 [Supabase Fallback] Found \(myPlaceIds.count) place IDs from my_places")
        } catch {
            print("⚠️ [Supabase Fallback] Error fetching my_places: \(error)")
        }
        
        // Get from favorites
        do {
            let favoriteRecords: [FavoriteRecord] = try await supabase.client
                .from("favorites")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let favoriteIds = favoriteRecords.map { $0.place_id }
            allPlaceIds.formUnion(favoriteIds)
            print("🔍 [Supabase Fallback] Found \(favoriteIds.count) place IDs from favorites")
        } catch {
            print("⚠️ [Supabase Fallback] Error fetching favorites: \(error)")
        }
        
        // Get from place_list_items (via user's lists)
        do {
            // First get user's list IDs
            struct ListIdOnly: Codable {
                let id: String
            }
            
            let userLists: [ListIdOnly] = try await supabase.client
                .from("place_lists")
                .select("id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let listIds = userLists.map { $0.id }
            print("🔍 [Supabase Fallback] Found \(listIds.count) lists for user")
            
            if !listIds.isEmpty {
                // Get ALL place_list_items for those lists
                let listItems: [PlaceListItemRecord] = try await supabase.client
                    .from("place_list_items")
                    .select()
                    .in("list_id", values: listIds)
                    .execute()
                    .value
                let listItemIds = listItems.map { $0.place_id }
                allPlaceIds.formUnion(listItemIds)
                print("🔍 [Supabase Fallback] Found \(listItemIds.count) place IDs from place_list_items")
            }
        } catch {
            print("⚠️ [Supabase Fallback] Error fetching place_list_items: \(error)")
        }
        
        // Step 2: Fetch all place details in one query
        guard !allPlaceIds.isEmpty else {
            print("⚠️ [Supabase Fallback] No place IDs found from any source")
            return []
        }
        
        print("🚀 [Supabase Fallback] Fetching details for \(allPlaceIds.count) unique places...")
        
        let placeRecords: [PlaceRecord] = try await supabase.client
            .from("places")
            .select()
            .in("id", values: Array(allPlaceIds))
            .execute()
            .value
        
        let places = placeRecords.map { convertToDetailPlace($0) }
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ [Supabase] Fetched \(places.count) total places in \(String(format: "%.2f", duration))s (via fallback)")
        print("   - From my_places, favorites, and all \(allPlaceIds.count) place_list_items")
        
        return places
    }
    
    // MARK: - My Places
    
    /// Fetch user's personally created/saved places from my_places table
    func fetchMyPlaces(userId: String) async throws -> [DetailPlace] {
        print("🔍 [Supabase] Fetching my_places for user: \(userId)")
        
        // First get my_places records to get place IDs
        let myPlacesRecords: [MyPlaceRecord] = try await supabase.client
            .from("my_places")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        print("🔍 [Supabase] Found \(myPlacesRecords.count) my_places records")
        
        let placeIds = myPlacesRecords.map { $0.place_id }
        
        guard !placeIds.isEmpty else {
            print("🔍 [Supabase] No my_places found")
            return []
        }
        
        print("🔍 [Supabase] Fetching details for \(placeIds.count) my_places")
        
        // Then fetch the actual place details
        let response: [PlaceRecord] = try await supabase.client
            .from("places")
            .select()
            .in("id", values: placeIds)
            .execute()
            .value
        
        let places = response.map { convertToDetailPlace($0) }
        print("✅ [Supabase] Successfully fetched \(places.count) my_places")
        
        return places
    }
    
    func fetchMyPlaces(userId: String, completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        Task {
            do {
                let places = try await fetchMyPlaces(userId: userId)
                completion(places, nil)
            } catch {
                print("❌ [Supabase] Error fetching my_places: \(error)")
                completion(nil, error)
            }
        }
    }
    
    // MARK: - Place Creation
    
    func addToAllPlaces(place: DetailPlace, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                print("📍 [Supabase] Adding place to all_places: \(place.name)")
                
                // Convert DetailPlace to PlaceRecord for Supabase
                let placeRecord = convertToPlaceRecord(place)
                
                let response: PlaceRecord = try await supabase.client
                    .from("places")
                    .insert(placeRecord)
                    .select()
                    .single()
                    .execute()
                    .value
                
                print("✅ [Supabase] Successfully added place to all_places: \(place.name)")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error adding place to all_places: \(error)")
                completion(error)
            }
        }
    }
    
    func addToMyPlaces(userId: String, place: DetailPlace, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                print("📍 [Supabase] Adding place to my_places for user: \(userId)")
                
                let myPlaceRecord = MyPlaceRecord(
                    id: UUID().uuidString,
                    user_id: userId,
                    place_id: place.id.uuidString,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                let response: MyPlaceRecord = try await supabase.client
                    .from("my_places")
                    .insert(myPlaceRecord)
                    .select()
                    .single()
                    .execute()
                    .value
                
                print("✅ [Supabase] Successfully added place to my_places for user: \(userId)")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error adding place to my_places: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Viewport Queries
    
    /// Fetch places within a geographic viewport (bounding box)
    /// Uses PostGIS for efficient spatial queries
    func fetchPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [DetailPlace] {
        print("🗺️ [Supabase] Fetching places in viewport: N=\(northLat), S=\(southLat), E=\(eastLng), W=\(westLng)")
        
        // Query places where user has saved them (my_places, favorites, or place_list_items)
        // Using a more efficient approach: get user's place IDs first, then filter by viewport
        
        // Get all place IDs the user has saved (my_places + favorites + place_list_items)
        let myPlacesIds = try await fetchUserPlaceIds(userId: userId)
        
        guard !myPlacesIds.isEmpty else {
            print("🗺️ [Supabase] No places found for user")
            return []
        }
        
        // Fetch places that are both in the user's collections AND in the viewport
        // Using ST_MakeEnvelope for bbox query
        let query = """
        id.in.(\(myPlacesIds.map { "\($0)" }.joined(separator: ",")))
        """
        
        let response: [PlaceRecord] = try await supabase.client
            .from("places")
            .select()
            .in("id", values: myPlacesIds)
            .gte("latitude", value: southLat)
            .lte("latitude", value: northLat)
            .gte("longitude", value: westLng)
            .lte("longitude", value: eastLng)
            .execute()
            .value
        
        let places = response.map { convertToDetailPlace($0) }
        print("✅ [Supabase] Found \(places.count) places in viewport")
        
        return places
    }
    
    /// Helper to get all place IDs associated with a user
    private func fetchUserPlaceIds(userId: String) async throws -> [String] {
        var placeIds = Set<String>()
        
        // Get from my_places
        do {
            let myPlaces: [MyPlaceRecord] = try await supabase.client
                .from("my_places")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let myPlaceIds = myPlaces.map { $0.place_id }
            placeIds.formUnion(myPlaceIds)
            print("🔍 [Supabase] Found \(myPlaceIds.count) place IDs from my_places")
        } catch {
            print("⚠️ [Supabase] Error fetching my_places for user IDs: \(error)")
        }
        
        // Get from favorites
        do {
            let favorites: [FavoriteRecord] = try await supabase.client
                .from("favorites")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            let favoriteIds = favorites.map { $0.place_id }
            placeIds.formUnion(favoriteIds)
            print("🔍 [Supabase] Found \(favoriteIds.count) place IDs from favorites: \(favoriteIds)")
        } catch {
            print("⚠️ [Supabase] Error fetching favorites for user IDs: \(error)")
        }
        
        // Get from place_list_items via place_lists
        do {
            // Query place_list_items with just the needed fields
            struct ListIdOnly: Codable {
                let id: String
            }
            
            let userLists: [ListIdOnly] = try await supabase.client
                .from("place_lists")
                .select("id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let listIds = userLists.map { $0.id }
            print("🔍 [Supabase] Found \(listIds.count) list IDs for user")
            
            if !listIds.isEmpty {
                // Then get place_list_items for those lists
                let listItems: [PlaceListItemRecord] = try await supabase.client
                    .from("place_list_items")
                    .select()
                    .in("list_id", values: listIds)
                    .execute()
                    .value
                let listItemIds = listItems.map { $0.place_id }
                placeIds.formUnion(listItemIds)
                print("🔍 [Supabase] Found \(listItemIds.count) place IDs from place_list_items")
            }
        } catch {
            print("⚠️ [Supabase] Error fetching place_list_items for user IDs: \(error)")
        }
        
        print("🔍 [Supabase] Found \(placeIds.count) total unique place IDs for user")
        
        return Array(placeIds)
    }
    
    func fetchPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String, completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        Task {
            do {
                let places = try await fetchPlacesInViewport(northLat: northLat, southLat: southLat, eastLng: eastLng, westLng: westLng, userId: userId)
                completion(places, nil)
            } catch {
                print("❌ [Supabase] Error fetching viewport places: \(error)")
                completion(nil, error)
            }
        }
    }
    
    // MARK: - Add/Remove Favorites
    
    func addFavorite(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("favorites")
                    .insert([
                        "user_id": userId,
                        "place_id": placeId
                    ])
                    .execute()
                
                print("✅ [Supabase] Added favorite for place \(placeId)")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error adding favorite: \(error)")
                completion(error)
            }
        }
    }
    
    func removeFavorite(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await supabase.client
                    .from("favorites")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("place_id", value: placeId)
                    .execute()
                
                print("✅ [Supabase] Removed favorite for place \(placeId)")
                completion(nil)
            } catch {
                print("❌ [Supabase] Error removing favorite: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertToDetailPlace(_ record: PlaceRecord) -> DetailPlace {
        // Create a DetailPlace with the basic required fields
        var place = DetailPlace(
            id: UUID(uuidString: record.id) ?? UUID(),
            name: record.name,
            address: record.address,
            city: record.city
        )
        
        // Set optional fields
        place.mapboxId = record.mapbox_id
        place.categories = record.categories
        place.phone = record.phone
        place.rating = record.rating
        place.userRatingsTotal = record.user_ratings_total
        place.openHours = record.open_hours
        place.description = record.description_text
        place.priceLevel = record.price_level
        place.reservable = record.reservable
        place.servesBreakfast = record.serves_breakfast
        place.serversLunch = record.serves_lunch
        place.serversDinner = record.serves_dinner
        place.Instagram = record.instagram
        place.X = record.x
        place.photoUrls = record.photo_urls
        place.googlePlaceId = record.google_place_id
        place.source = record.source
        place.createdAt = record.created_at
        place.isCustom = record.is_custom
        
        // Handle coordinate from PostGIS geometry
        if let locationData = record.location {
            // Try to parse the GeoJSON format: {"type":"Point","coordinates":[-122.4,37.8]}
            if let coords = locationData.coordinates, coords.count >= 2 {
                place.coordinate = CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
            } else {
                print("⚠️ [Supabase] Could not parse location coordinates: \(locationData.coordinates ?? [])")
            }
        } else {
            print("🔍 [Supabase] No location found for place: \(record.name)")
        }
        
        return place
    }

    // MARK: - Fetch Place Lists
    
    /// Helper to fetch places for a specific list
    private func fetchPlacesForList(listId: String) async throws -> [Place] {
        // Get place_list_items for this list
        let listItems: [PlaceListItemRecord] = try await supabase.client
            .from("place_list_items")
            .select()
            .eq("list_id", value: listId)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        guard !listItems.isEmpty else {
            return []
        }
        
        let placeIds = listItems.map { $0.place_id }
        
        // Fetch place details
        let placeRecords: [PlaceRecord] = try await supabase.client
            .from("places")
            .select()
            .in("id", values: placeIds)
            .execute()
            .value
        
        // Convert to simplified Place objects for PlaceList
        let places = placeRecords.map { record in
            Place(
                id: UUID(uuidString: record.id) ?? UUID(),
                name: record.name,
                address: record.address ?? ""
            )
        }
        
        print("🔍 [Supabase] Fetched \(places.count) places for list \(listId)")
        return places
    }
    
    /// Fetch places for multiple lists efficiently (for first 6 visible lists)
    func fetchPlacesForLists(listIds: [String], maxPlacesPerList: Int = 6) async throws -> [String: [DetailPlace]] {
        print("🚀 [Supabase] Fetching places for \(listIds.count) lists (max \(maxPlacesPerList) per list)")
        print("🔍 [Supabase] List IDs: \(listIds)")
        
        var result: [String: [DetailPlace]] = [:]
        
        // Get all place_list_items for these lists
        let listItems: [PlaceListItemRecord] = try await supabase.client
            .from("place_list_items")
            .select()
            .in("list_id", values: listIds)
            .order("list_id", ascending: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        print("🔍 [Supabase] Found \(listItems.count) place_list_items for \(listIds.count) lists")
        
        // Group by list_id and limit to maxPlacesPerList per list
        var listPlaceIds: [String: [String]] = [:]
        for item in listItems {
            if listPlaceIds[item.list_id] == nil {
                listPlaceIds[item.list_id] = []
            }
            if listPlaceIds[item.list_id]!.count < maxPlacesPerList {
                listPlaceIds[item.list_id]!.append(item.place_id)
            }
        }
        
        // Get all unique place IDs
        let allPlaceIds = Set(listPlaceIds.values.flatMap { $0 })
        print("🔍 [Supabase] Fetching details for \(allPlaceIds.count) unique places")
        
        // Fetch all place details in one query
        let placeRecords: [PlaceRecord] = try await supabase.client
            .from("places")
            .select()
            .in("id", values: Array(allPlaceIds))
            .execute()
            .value
        
        // Convert to DetailPlace objects
        let placesMap = Dictionary(uniqueKeysWithValues: placeRecords.map { record in
            (record.id, convertToDetailPlace(record))
        })
        
        // Group places back by list_id
        for (listId, placeIds) in listPlaceIds {
            let places = placeIds.compactMap { placesMap[$0] }
            result[listId] = places
            print("🔍 [Supabase] List \(listId): \(places.count) places (from \(placeIds.count) place IDs)")
        }
        
        // Ensure all requested lists have an entry (even if empty)
        for listId in listIds {
            if result[listId] == nil {
                result[listId] = []
                print("🔍 [Supabase] List \(listId): 0 places (no place_list_items found)")
            }
        }
        
        print("✅ [Supabase] Successfully fetched places for \(result.count) lists")
        return result
    }
    
    /// Get place count for multiple lists efficiently
    func getPlaceCountsForLists(listIds: [String]) async throws -> [String: Int] {
        print("🔍 [Supabase] Getting place counts for \(listIds.count) lists")
        
        // Get place counts for all lists in one query
        let listItems: [PlaceListItemRecord] = try await supabase.client
            .from("place_list_items")
            .select("list_id")
            .in("list_id", values: listIds)
            .execute()
            .value
        
        // Count places per list
        var counts: [String: Int] = [:]
        for item in listItems {
            counts[item.list_id, default: 0] += 1
        }
        
        // Ensure all requested lists have an entry (even if 0)
        for listId in listIds {
            if counts[listId] == nil {
                counts[listId] = 0
            }
        }
        
        print("✅ [Supabase] Got place counts for \(counts.count) lists")
        return counts
    }
    
    func fetchLists(userId: String, completion: @escaping ([PlaceList]) -> Void) {
        Task {
            do {
                print("🔍 [Supabase] Querying place_lists for user_id: \(userId)")
                print("🔍 [Supabase] User ID type: \(type(of: userId))")
                print("🔍 [Supabase] User ID length: \(userId.count)")
                print("🔍 [Supabase] User ID characters: \(Array(userId))")
                
                let records: [PlaceListRecord] = try await supabase.client
                    .from("place_lists")
                    .select()
                    .eq("user_id", value: userId)
                    .order("sort_order", ascending: true)
                    .execute()
                    .value

                print("🔍 [Supabase] Raw database response: \(records.count) records")

                // Convert records to PlaceLists WITHOUT fetching places
                // Places will be loaded lazily when lists are opened
                let placeLists = records.map { record in
                    PlaceList(
                        id: UUID(uuidString: record.id) ?? UUID(),
                        name: record.name,
                        places: [], // Will be loaded lazily via place_list_items query
                        city: "",
                        emoji: "📍", // Default emoji
                        image: record.cover_image_url,
                        sortOrder: record.sort_order,
                        averageCoordinate: parseGeometryToCoordinate(record.average_location),
                        lastCoordinateUpdate: nil
                    )
                }

                print("✅ [Supabase] Fetched \(placeLists.count) place lists (metadata only, places load on-demand)")
                
                completion(placeLists)

            } catch {
                print("❌ [Supabase] Error fetching place lists: \(error)")
                completion([])
            }
        }
    }
    
    /// Fetches place lists sorted by proximity to user's current location
    func fetchListsByProximity(userId: String, userLocation: CLLocationCoordinate2D?, completion: @escaping ([PlaceList]) -> Void) {
        Task {
            do {
                print("🔍 [Supabase] Querying place_lists by proximity for user_id: \(userId)")
                
                var records: [PlaceListRecord]
                
                if let userLocation = userLocation {
                    // Use the proximity-based SQL function
                    print("📍 [Supabase] Using proximity sorting with user location: \(userLocation.latitude), \(userLocation.longitude)")
                    
                    struct ProximityParams: Encodable {
                        let p_user_id: String
                        let p_user_lat: Double
                        let p_user_lng: Double
                    }
                    
                    let params = ProximityParams(
                        p_user_id: userId,
                        p_user_lat: userLocation.latitude,
                        p_user_lng: userLocation.longitude
                    )
                    
                    records = try await supabase.client
                        .rpc("get_user_place_lists_by_proximity", params: params)
                        .execute()
                        .value
                } else {
                    // Fallback to regular sorting if no location available
                    print("📍 [Supabase] No user location available, using regular sort_order")
                    records = try await supabase.client
                        .from("place_lists")
                        .select()
                        .eq("user_id", value: userId)
                        .order("sort_order", ascending: true)
                        .execute()
                        .value
                }

                print("🔍 [Supabase] Raw database response: \(records.count) records")

                // Convert records to PlaceLists WITHOUT fetching places
                // Places will be loaded lazily when lists are opened
                let placeLists = records.map { record in
                    PlaceList(
                        id: UUID(uuidString: record.id) ?? UUID(),
                        name: record.name,
                        places: [], // Will be loaded lazily via place_list_items query
                        city: "",
                        emoji: "📍", // Default emoji
                        image: record.cover_image_url,
                        sortOrder: record.sort_order,
                        averageCoordinate: parseGeometryToCoordinate(record.average_location),
                        lastCoordinateUpdate: nil
                    )
                }

                print("✅ [Supabase] Fetched \(placeLists.count) place lists sorted by proximity")
                
                completion(placeLists)

            } catch {
                print("❌ [Supabase] Error fetching place lists by proximity: \(error)")
                completion([])
            }
        }
    }

    func fetchLists(userId: String) async throws -> [PlaceList] {
        print("📋 [Supabase] Fetching place lists for user: \(userId)")

        do {
            // Try querying with the profile user ID first
            var records: [PlaceListRecord] = try await supabase.client
                .from("place_lists")
                .select()
                .eq("user_id", value: userId)
                .order("sort_order", ascending: true)
                .execute()
                .value
            
            // If no records found, try with the Supabase auth user ID
            if records.isEmpty {
                do {
                    let session = try await supabase.client.auth.session
                    let authUserId = session.user.id.uuidString
                    records = try await supabase.client
                        .from("place_lists")
                        .select()
                        .eq("user_id", value: authUserId)
                        .order("sort_order", ascending: true)
                        .execute()
                        .value
                } catch {
                    print("❌ [Supabase] Error getting auth session for fallback query: \(error)")
                }
            }

            // Convert records to PlaceLists WITHOUT fetching places
            // Places will be loaded lazily when lists are opened
            let placeLists = records.map { record in
                PlaceList(
                    id: UUID(uuidString: record.id) ?? UUID(),
                    name: record.name,
                    places: [], // Will be loaded lazily via place_list_items query
                    city: "",
                    emoji: "📍", // Default emoji
                    image: record.cover_image_url,
                    sortOrder: record.sort_order,
                    averageCoordinate: parseGeometryToCoordinate(record.average_location),
                    lastCoordinateUpdate: nil
                )
            }

            print("✅ [Supabase] Fetched \(placeLists.count) place lists (metadata only)")
            
            return placeLists

        } catch {
            print("❌ [Supabase] Error fetching place lists: \(error)")
            throw error
        }
    }
    
    /// Async version: Fetches place lists sorted by proximity to user's current location
    func fetchListsByProximity(userId: String, userLocation: CLLocationCoordinate2D?) async throws -> [PlaceList] {
        print("📋 [Supabase] Fetching place lists by proximity for user: \(userId)")
        
        do {
            var records: [PlaceListRecord]
            
            if let userLocation = userLocation {
                // Use the proximity-based SQL function
                print("📍 [Supabase] Using proximity sorting with user location: \(userLocation.latitude), \(userLocation.longitude)")
                
                struct ProximityParams: Encodable {
                    let p_user_id: String
                    let p_user_lat: Double
                    let p_user_lng: Double
                }
                
                let params = ProximityParams(
                    p_user_id: userId,
                    p_user_lat: userLocation.latitude,
                    p_user_lng: userLocation.longitude
                )
                
                records = try await supabase.client
                    .rpc("get_user_place_lists_by_proximity", params: params)
                    .execute()
                    .value
            } else {
                // Fallback to regular sorting if no location available
                print("📍 [Supabase] No user location available, using regular sort_order")
                records = try await supabase.client
                    .from("place_lists")
                    .select()
                    .eq("user_id", value: userId)
                    .order("sort_order", ascending: true)
                    .execute()
                    .value
            }

            print("🔍 [Supabase] Raw database response: \(records.count) records")

            // Convert records to PlaceLists WITHOUT fetching places
            // Places will be loaded lazily when lists are opened
            let placeLists = records.map { record in
                PlaceList(
                    id: UUID(uuidString: record.id) ?? UUID(),
                    name: record.name,
                    places: [], // Will be loaded lazily via place_list_items query
                    city: "",
                    emoji: "📍", // Default emoji
                    image: record.cover_image_url,
                    sortOrder: record.sort_order,
                    averageCoordinate: parseGeometryToCoordinate(record.average_location),
                    lastCoordinateUpdate: nil
                )
            }

            print("✅ [Supabase] Fetched \(placeLists.count) place lists sorted by proximity")
            
            return placeLists

        } catch {
            print("❌ [Supabase] Error fetching place lists by proximity: \(error)")
            throw error
        }
    }
}

// MARK: - Supabase Data Models

struct PlaceRecord: Codable {
    let id: String
    let name: String
    let address: String?
    let city: String?
    let mapbox_id: String?
    let location: LocationData? // PostGIS geometry as custom struct
    let categories: [String]?
    let phone: String?
    let rating: Double?
    let user_ratings_total: Int?
    let open_hours: [String]?
    let description_text: String?
    let price_level: String?
    let reservable: Bool?
    let serves_breakfast: Bool?
    let serves_lunch: Bool?
    let serves_dinner: Bool?
    let instagram: String?
    let x: String?
    let photo_urls: [String]?
    let google_place_id: String?
    let source: String?
    let created_at: String?
    let is_custom: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, city, mapbox_id
        case location, categories, phone, rating
        case user_ratings_total, open_hours, description_text, price_level, reservable
        case serves_breakfast, serves_lunch, serves_dinner, instagram, x, photo_urls
        case google_place_id, source, created_at, is_custom
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        mapbox_id = try container.decodeIfPresent(String.self, forKey: .mapbox_id)
        location = try container.decodeIfPresent(LocationData.self, forKey: .location)
        categories = try container.decodeIfPresent([String].self, forKey: .categories)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        user_ratings_total = try container.decodeIfPresent(Int.self, forKey: .user_ratings_total)
        description_text = try container.decodeIfPresent(String.self, forKey: .description_text)
        price_level = try container.decodeIfPresent(String.self, forKey: .price_level)
        reservable = try container.decodeIfPresent(Bool.self, forKey: .reservable)
        serves_breakfast = try container.decodeIfPresent(Bool.self, forKey: .serves_breakfast)
        serves_lunch = try container.decodeIfPresent(Bool.self, forKey: .serves_lunch)
        serves_dinner = try container.decodeIfPresent(Bool.self, forKey: .serves_dinner)
        instagram = try container.decodeIfPresent(String.self, forKey: .instagram)
        x = try container.decodeIfPresent(String.self, forKey: .x)
        photo_urls = try container.decodeIfPresent([String].self, forKey: .photo_urls)
        google_place_id = try container.decodeIfPresent(String.self, forKey: .google_place_id)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        is_custom = try container.decodeIfPresent(Bool.self, forKey: .is_custom)
        
        // Handle open_hours - skip if it can't be decoded as [String]
        do {
            open_hours = try container.decodeIfPresent([String].self, forKey: .open_hours)
        } catch {
            print("⚠️ [Supabase] Could not decode open_hours as [String], setting to nil: \(error)")
            open_hours = nil
        }
    }
}

struct LocationData: Codable {
    let type: String?
    let coordinates: [Double]?
    
    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }
}

struct FavoriteRecord: Codable {
    let user_id: String
    let place_id: String
}

struct MyPlaceRecord: Codable {
    let user_id: String
    let place_id: String
    let timestamp: String?
}

struct PlaceListItemRecord: Codable {
    let place_id: String
    let list_id: String
    let sort_order: Int?
}

