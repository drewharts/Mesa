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
    
    private init() {    }
    
    // MARK: - Place Deletion
    
    func deletePlaceFromMyPlaces(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {                
                try await supabase.client
                    .from("my_places")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("place_id", value: placeId)
                    .execute()
                
                completion(nil)
            } catch {
                print("❌ [Supabase] Error deleting place from my_places: \(error)")
                completion(error)
            }
        }
    }
    
    func deletePlaceFromAllPlaces(placeId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                
                // First check if this is a custom place
                let placeRecord: PlaceRecord = try await supabase.client
                    .from("places")
                    .select()
                    .eq("id", value: placeId)
                    .single()
                    .execute()
                    .value
                
                // Only delete custom places from all_places
                if placeRecord.is_custom == true {
                    try await supabase.client
                        .from("places")
                        .delete()
                        .eq("id", value: placeId)
                        .execute()
                    
                } else {
                    print("⚠️ [Supabase] Cannot delete non-custom place from all_places")
                }
                
                completion(nil)
            } catch {
                print("❌ [Supabase] Error deleting place from all_places: \(error)")
                completion(error)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Struct for inserting places into Supabase
    private struct PlaceInsertData: Encodable {
        let id: String
        let name: String
        let address: String?
        let city: String?
        let description: String?
        let location: String? // PostGIS geometry as WKT string
        let geohash: String?
        let rating: Double?
        let rating_count: Int?
        let price_level: String?
        let categories: [String]?
        let phone: String?
        let website: String?
        let menu_url: String?
        let instagram: String?
        let twitter: String?
        let google_places_id: String?
        let mapbox_id: String?
        let fid: String?
        let cid: String?
        let thumbnail_url: String?
        let photo_urls: [String]?
        let open_hours: [String]?
        let reservable: Bool?
        let serves_breakfast: Bool?
        let serves_lunch: Bool?
        let serves_dinner: Bool?
        let source: String?
        let updated_at: String?
        let is_custom: Bool
    }
    
    /// Converts DetailPlace to PlaceInsertData for Supabase insertion
    private func convertToPlaceData(_ place: DetailPlace) -> PlaceInsertData {
        // Convert coordinate to PostGIS geometry string
        var locationString: String? = nil
        if let coordinate = place.coordinate {
            locationString = "POINT(\(coordinate.longitude) \(coordinate.latitude))"
        }
        
        return PlaceInsertData(
            id: place.id.uuidString,
            name: place.name,
            address: place.address,
            city: place.city,
            description: place.description,
            location: locationString,
            geohash: nil, // Not available in DetailPlace
            rating: place.rating,
            rating_count: place.userRatingsTotal,
            price_level: place.priceLevel,
            categories: place.categories,
            phone: place.phone,
            website: nil, // Not available in DetailPlace
            menu_url: nil, // Not available in DetailPlace
            instagram: place.Instagram,
            twitter: nil, // Not available in DetailPlace
            google_places_id: place.googlePlaceId,
            mapbox_id: place.mapboxId,
            fid: nil, // Not available in DetailPlace
            cid: nil, // Not available in DetailPlace
            thumbnail_url: nil, // Not available in DetailPlace
            photo_urls: place.photoUrls,
            open_hours: place.openHours,
            reservable: place.reservable,
            serves_breakfast: place.servesBreakfast,
            serves_lunch: place.serversLunch,
            serves_dinner: place.serversDinner,
            source: place.isCustom == true ? "custom" : place.source,
            updated_at: nil, // Let database handle this
            is_custom: place.isCustom ?? false
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
        let user_id: String?
        let name: String
        let description: String?
        let average_location: String? // PostGIS geometry (cast to text in query)
        let is_public: Bool?
        let image: String?
        let created_at: String?
        let updated_at: String?
        let distance_meters: Double? // Distance from user location (when sorted by proximity)
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
                let response: [PlaceRecord] = try await supabase.client
                    .from("places")
                    .select()
                    .execute()
                    .value
                
                let places = response.map { convertToDetailPlace($0) }
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
                print("❌ [Supabase] Error fetching profile favorites: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func fetchProfileFavorites(userId: String) async throws -> [DetailPlace] {
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
        
        do {
            // Try using the optimized SQL function first
            let response: [PlaceRecord] = try await supabase.client
                .rpc("get_all_user_places", params: ["p_user_id": userId])
                .execute()
                .value
            
            let places = response.map { convertToDetailPlace($0) }
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
            }
        } catch {
            print("⚠️ [Supabase Fallback] Error fetching place_list_items: \(error)")
        }
        
        // Step 2: Fetch all place details in one query
        guard !allPlaceIds.isEmpty else {
            return []
        }
        
        let placeRecords: [PlaceRecord] = try await supabase.client
            .from("places")
            .select()
            .in("id", values: Array(allPlaceIds))
            .execute()
            .value
        
        let places = placeRecords.map { convertToDetailPlace($0) }
        
        return places
    }
    
    // MARK: - My Places
    
    /// Fetch user's personally created/saved places from my_places table
    func fetchMyPlaces(userId: String) async throws -> [DetailPlace] {
        // First get my_places records to get place IDs
        let myPlacesRecords: [MyPlaceRecord] = try await supabase.client
            .from("my_places")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let placeIds = myPlacesRecords.map { $0.place_id }
        
        guard !placeIds.isEmpty else {
            return []
        }
        
        // Then fetch the actual place details
        let response: [PlaceRecord] = try await supabase.client
            .from("places")
            .select()
            .in("id", values: placeIds)
            .execute()
            .value
        
        let places = response.map { convertToDetailPlace($0) }
        
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
    
    // MARK: - Image Loading
    
    /// Batch fetch place images from reviews or TikTok thumbnails
    /// Uses the get_latest_review_photo SQL function for efficiency
    func fetchPlaceImages(for placeIds: [String]) async throws -> [String: String] {
        guard !placeIds.isEmpty else {
            return [:]
        }
        
        // Call the RPC function
        let response = try await supabase.client
            .rpc("get_latest_review_photo", params: ["p_place_ids": placeIds])
            .execute()
        
        // Parse the response
        struct ImageResult: Decodable {
            let place_id: String
            let image_url: String?
        }
        
        let results = try JSONDecoder().decode([ImageResult].self, from: response.data)
        
        // Convert to dictionary, filtering out nil image_urls
        var imageMap: [String: String] = [:]
        for result in results {
            if let imageUrl = result.image_url {
                imageMap[result.place_id] = imageUrl
            }
        }
        
        return imageMap
    }
    
    // MARK: - Place Creation
    
    /// Test method to verify Supabase connection
    func testSupabaseConnection(completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                // Test with a simple count query instead of trying to decode PlaceRecord
                let response = try await supabase.client
                    .from("places")
                    .select("id", head: true, count: .exact)
                    .execute()
                
                completion(true, nil)
            } catch {
                print("❌ [Supabase] Connection test failed: \(error)")
                completion(false, error)
            }
        }
    }
    
    func addToAllPlaces(place: DetailPlace, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                // Convert DetailPlace to dictionary for Supabase insertion
                let placeData = convertToPlaceData(place)
                
                let response: [PlaceRecord] = try await supabase.client
                    .from("places")
                    .insert(placeData)
                    .select()
                    .execute()
                    .value
                
                completion(nil)
            } catch {
                print("❌ [Supabase] Error adding place to all_places: \(error)")
                print("❌ [Supabase] Error details: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    func addToMyPlaces(userId: String, place: DetailPlace, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                // Convert coordinate to LocationData struct (same format as PlaceRecord)
                var locationData: LocationData? = nil
                if let coordinate = place.coordinate {
                    locationData = LocationData(
                        type: "Point",
                        coordinates: [coordinate.longitude, coordinate.latitude]
                    )
                }
                
                let myPlaceRecord = MyPlaceRecord(
                    user_id: userId,
                    place_id: place.id.uuidString,
                    name: place.name,
                    coordinate: locationData
                )
                
                let response: MyPlaceRecord = try await supabase.client
                    .from("my_places")
                    .insert(myPlaceRecord)
                    .select()
                    .single()
                    .execute()
                    .value
                
                completion(nil)
            } catch {
                print("❌ [Supabase] Error adding place to my_places: \(error)")
                print("❌ [Supabase] Error details: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    // MARK: - Viewport Queries
    
    /// Fetch place annotations for map markers within a geographic viewport
    /// Uses the optimized PostgreSQL function with user tracking
    func fetchPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [PlaceAnnotation] {
        do {
            // Use the optimized PostgreSQL function
            struct ViewportParams: Encodable {
                let p_user_id: String
                let p_min_lon: Double
                let p_min_lat: Double
                let p_max_lon: Double
                let p_max_lat: Double
            }
            
            let params = ViewportParams(
                p_user_id: userId,
                p_min_lon: westLng,
                p_min_lat: southLat,
                p_max_lon: eastLng,
                p_max_lat: northLat
            )
            
            let response: [PlaceAnnotation] = try await supabase.client
                .rpc("get_visible_annotations_with_users", params: params)
                .execute()
                .value
            
            return response
        } catch {
            print("❌ [Supabase] Error fetching place annotations: \(error)")
            throw error
        }
    }
    
    // Fallback method removed - we now use the optimized PostgreSQL function exclusively
    
    // fetchFriendsPlacesInViewport removed - the main function already includes friends' places
    
    /// ✅ NEW: Fetch favorite place IDs only (not full place documents) - SUPER FAST!
    func fetchFavoritePlaceIds(userId: String) async throws -> [String] {
        let favoriteRecords: [FavoriteRecord] = try await supabase.client
            .from("favorites")
            .select("place_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let favoriteIds = favoriteRecords.map { $0.place_id }
        
        return favoriteIds
    }
    
    /// ✅ NEW: Fetch my place IDs only (not full place documents) - SUPER FAST!
    func fetchMyPlaceIds(userId: String) async throws -> [String] {
        let myPlacesRecords: [MyPlaceRecord] = try await supabase.client
            .from("my_places")
            .select("place_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let myPlaceIds = myPlacesRecords.map { $0.place_id }
        
        return myPlaceIds
    }
    
    /// ✅ NEW: Fetch list metadata only (not full place documents) - SUPER FAST!
    func fetchListMetadata(userId: String) async throws -> [PlaceList] {
        let listRecords: [PlaceListRecord] = try await supabase.client
            .from("place_lists")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        let lists = listRecords.map { convertToPlaceList($0) }
        
        return lists
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
            }
        } catch {
            print("⚠️ [Supabase] Error fetching place_list_items for user IDs: \(error)")
        }
        
        return Array(placeIds)
    }
    
    func fetchPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String, completion: @escaping ([PlaceAnnotation]?, Error?) -> Void) {
        Task {
            do {
                let annotations = try await fetchPlacesInViewport(northLat: northLat, southLat: southLat, eastLng: eastLng, westLng: westLng, userId: userId)
                completion(annotations, nil)
            } catch {
                print("❌ [Supabase] Error fetching viewport places: \(error)")
                completion(nil, error)
            }
        }
    }
    
    // MARK: - User Photos for Annotations
    
    /// Fetch profile photos for all followed users (for custom annotation views)
    func fetchFollowedUsersPhotos(userId: String) async throws -> [FollowedUserPhoto] {
        do {
            struct UserPhotoParams: Encodable {
                let p_user_id: String
            }
            
            let params = UserPhotoParams(p_user_id: userId)
            
            let response: [FollowedUserPhoto] = try await supabase.client
                .rpc("get_followed_users_photos", params: params)
                .execute()
                .value
            
            return response
        } catch {
            print("❌ [Supabase] Error fetching followed users' photos: \(error)")
            throw error
        }
    }
    
    // MARK: - Custom Place Creator
    
    /// Fetch the creator of a custom place
    /// Returns nil if the place is not a custom place or has no creator
    func fetchCustomPlaceCreator(placeId: String) async throws -> CustomPlaceCreator? {
        do {
            struct CreatorParams: Encodable {
                let p_place_id: String
            }
            
            let params = CreatorParams(p_place_id: placeId)
            
            let response: [CustomPlaceCreator] = try await supabase.client
                .rpc("get_custom_place_creator", params: params)
                .execute()
                .value
            
            return response.first
        } catch {
            print("❌ [Supabase] Error fetching custom place creator: \(error)")
            throw error
        }
    }
    
    // MARK: - On-Demand Place Details
    
    /// Fetch full place details for a specific place ID (called when user taps a marker)
    func fetchPlaceDetails(placeId: String) async throws -> DetailPlace? {
        do {
            let response: [PlaceRecord] = try await supabase.client
                .from("places")
                .select()
                .eq("id", value: placeId)
                .execute()
                .value
            
            guard let placeRecord = response.first else {
                return nil
            }
            
            let place = convertToDetailPlace(placeRecord)
            
            return place
        } catch {
            print("❌ [Supabase] Error fetching place details: \(error)")
            throw error
        }
    }
    
    /// Batch fetch full place details for multiple place IDs
    func fetchPlaceDetailsBatch(placeIds: [String]) async throws -> [DetailPlace] {
        guard !placeIds.isEmpty else { return [] }
        
        do {
            let response: [PlaceRecord] = try await supabase.client
                .from("places")
                .select()
                .in("id", values: placeIds)
                .execute()
                .value
            
            let places = response.map { convertToDetailPlace($0) }
            
            return places
        } catch {
            print("❌ [Supabase] Error batch fetching place details: \(error)")
            throw error
        }
    }

    // MARK: - Add/Remove Favorites
    
    func addFavorite(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                // Only store the minimal required data - IDs and timestamp
                // Full place details can be fetched via JOIN when needed
                struct FavoriteInsert: Encodable {
                    let id: String
                    let user_id: String
                    let place_id: String
                    let timestamp: String
                }
                
                let insertData = FavoriteInsert(
                    id: UUID().uuidString,
                    user_id: userId,
                    place_id: placeId,
                    timestamp: ISO8601DateFormatter().string(from: Date())
                )
                
                try await supabase.client
                    .from("favorites")
                    .insert(insertData)
                    .execute()
                
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
        place.userRatingsTotal = record.rating_count
        // Convert open_hours from AnyCodable to [String] if possible
        if let openHoursData = record.open_hours {
            if let stringArray = openHoursData.value as? [String] {
                place.openHours = stringArray
            } else if let dictArray = openHoursData.value as? [[String: String]] {
                // Convert from [{ day: "Monday", hours: "11 AM–11 PM" }] to ["Monday: 11 AM–11 PM"]
                place.openHours = dictArray.compactMap { dict in
                    guard let day = dict["day"], let hours = dict["hours"] else { return nil }
                    return "\(day): \(hours)"
                }
            } else {
                print("⚠️ [Supabase] Could not convert open_hours to [String]: \(openHoursData.value)")
                place.openHours = nil
            }
        } else {
            place.openHours = nil
        }
        place.description = record.description
        place.priceLevel = record.price_level
        place.reservable = record.reservable
        place.servesBreakfast = record.serves_breakfast
        place.serversLunch = record.serves_lunch
        place.serversDinner = record.serves_dinner
        place.Instagram = record.instagram
        place.X = record.twitter // Note: DetailPlace doesn't have twitter field, using x instead
        place.photoUrls = record.photo_urls
        place.googlePlaceId = record.google_places_id
        place.source = record.source
        place.isCustom = record.is_custom
        
        // Handle coordinate from PostGIS geometry
        if let locationData = record.location {
            // Try to parse the GeoJSON format: {"type":"Point","coordinates":[-122.4,37.8]}
            if let coords = locationData.coordinates, coords.count >= 2 {
                place.coordinate = CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
            } else {
                print("⚠️ [Supabase] Could not parse location coordinates: \(locationData.coordinates ?? [])")
            }
        }
        
        return place
    }
    
    private func convertToPlaceList(_ record: PlaceListRecord) -> PlaceList {
        // Parse the average location from WKT format if available
        let averageCoordinate = parseGeometryToCoordinate(record.average_location)
        
        return PlaceList(
            id: UUID(uuidString: record.id) ?? UUID(),
            name: record.name,
            places: [], // Empty initially - places will be loaded separately
            city: "", // Not stored in database
            emoji: "📋", // Default emoji
            image: record.image,
            sortOrder: 0,
            averageCoordinate: averageCoordinate,
            lastCoordinateUpdate: nil
        )
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
        
        return places
    }
    
    /// Fetch places for multiple lists efficiently (for first 6 visible lists)
    func fetchPlacesForLists(listIds: [String], maxPlacesPerList: Int = 6) async throws -> [String: [DetailPlace]] {
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
        }
        
        // Ensure all requested lists have an entry (even if empty)
        for listId in listIds {
            if result[listId] == nil {
                result[listId] = []
            }
        }
        
        return result
    }
    
    /// Get place count for multiple lists efficiently
    func getPlaceCountsForLists(listIds: [String]) async throws -> [String: Int] {
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
        
        return counts
    }
    
    func fetchLists(userId: String, completion: @escaping ([PlaceList]) -> Void) {
        Task {
            do {
                let records: [PlaceListRecord] = try await supabase.client
                    .from("place_lists")
                    .select()
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                // Convert records to PlaceLists WITHOUT fetching places
                // Places will be loaded lazily when lists are opened
                let placeLists = records.map { record in
                    PlaceList(
                        id: UUID(uuidString: record.id) ?? UUID(),
                        name: record.name,
                        places: [], // Will be loaded lazily via place_list_items query
                        city: "",
                        emoji: "📍",
                        image: record.image,
                        sortOrder: 0,
                        averageCoordinate: parseGeometryToCoordinate(record.average_location),
                        lastCoordinateUpdate: nil
                    )
                }
                
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
                var records: [PlaceListRecord]
                
                if let userLocation = userLocation {
                    // Use the proximity-based SQL function
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
                    // Fallback to regular sorting if no location available - use created_at (newest first)
                    let selectColumns = "id, user_id, name, description, average_location::text, is_public, image, created_at, updated_at"
                    records = try await supabase.client
                        .from("place_lists")
                        .select(selectColumns)
                        .eq("user_id", value: userId)
                        .order("created_at", ascending: false)
                        .execute()
                        .value
                }

                // Convert records to PlaceLists WITHOUT fetching places
                // Places will be loaded lazily when lists are opened
                let placeLists = records.map { record in
                    PlaceList(
                        id: UUID(uuidString: record.id) ?? UUID(),
                        name: record.name,
                        places: [], // Will be loaded lazily via place_list_items query
                        city: "",
                        emoji: "📍",
                        image: record.image,
                        sortOrder: 0,
                        averageCoordinate: parseGeometryToCoordinate(record.average_location),
                        lastCoordinateUpdate: nil
                    )
                }
                
                completion(placeLists)

            } catch {
                print("❌ [Supabase] Error fetching place lists by proximity: \(error)")
                completion([])
            }
        }
    }

    func fetchLists(userId: String) async throws -> [PlaceList] {
        do {
            // Select specific columns and cast geometry to text
            let selectColumns = "id, user_id, name, description, average_location::text, is_public, image, created_at, updated_at"
            
            // Try querying with the profile user ID first
            var records: [PlaceListRecord] = try await supabase.client
                .from("place_lists")
                .select(selectColumns)
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // If no records found, try with the Supabase auth user ID
            if records.isEmpty {
                do {
                    let session = try await supabase.client.auth.session
                    let authUserId = session.user.id.uuidString
                    records = try await supabase.client
                        .from("place_lists")
                        .select(selectColumns)
                        .eq("user_id", value: authUserId)
                        .order("created_at", ascending: false)
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
                    emoji: "📍",
                    image: record.image,
                    sortOrder: 0,
                    averageCoordinate: parseGeometryToCoordinate(record.average_location),
                    lastCoordinateUpdate: nil
                )
            }
            
            return placeLists

        } catch {
            print("❌ [Supabase] Error fetching place lists: \(error)")
            throw error
        }
    }
    
    /// Create a new place list
    func createNewList(userId: String, name: String, city: String, emoji: String, image: String) async throws -> PlaceList {
        // Generate a new UUID for the list
        let listId = UUID().uuidString
        
        // Create the insert struct - only columns that exist in database
        struct NewPlaceListRecord: Encodable {
            let id: String
            let user_id: String
            let name: String
            let description: String?
            let image: String?
            let is_public: Bool
        }
        
        let newList = NewPlaceListRecord(
            id: listId,
            user_id: userId,
            name: name,
            description: nil,
            image: image.isEmpty ? nil : image,
            is_public: false
        )
        
        // Insert the new list
        let response: [PlaceListRecord] = try await supabase.client
            .from("place_lists")
            .insert(newList)
            .select()
            .execute()
            .value
        
        guard let createdRecord = response.first else {
            throw NSError(domain: "SupabasePlaceService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create list - no record returned"
            ])
        }
        
        let placeList = convertToPlaceList(createdRecord)
        
        return placeList
    }
    
    /// Async version: Fetches place lists sorted by proximity to user's current location
    func fetchListsByProximity(userId: String, userLocation: CLLocationCoordinate2D?) async throws -> [PlaceList] {
        do {
            var records: [PlaceListRecord]
            
            if let userLocation = userLocation {
                // Use the proximity-based SQL function
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
                // Fallback to regular sorting if no location available - use created_at (newest first)
                let selectColumns = "id, user_id, name, description, average_location::text, is_public, image, created_at, updated_at"
                records = try await supabase.client
                    .from("place_lists")
                    .select(selectColumns)
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }

            // Convert records to PlaceLists WITHOUT fetching places
            // Places will be loaded lazily when lists are opened
            let placeLists = records.map { record in
                PlaceList(
                    id: UUID(uuidString: record.id) ?? UUID(),
                    name: record.name,
                    places: [], // Will be loaded lazily via place_list_items query
                    city: "",
                    emoji: "📍",
                    image: record.image,
                    sortOrder: 0,
                    averageCoordinate: parseGeometryToCoordinate(record.average_location),
                    lastCoordinateUpdate: nil
                )
            }
            
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
    let description: String?
    let location: LocationData? // PostGIS geometry as custom struct
    let geohash: String?
    let rating: Double?
    let rating_count: Int?
    let price_level: String?
    let categories: [String]?
    let phone: String?
    let website: String?
    let menu_url: String?
    let instagram: String?
    let twitter: String?
    let google_places_id: String?
    let mapbox_id: String?
    let fid: String?
    let cid: String?
    let thumbnail_url: String?
    let photo_urls: [String]?
    let open_hours: AnyCodable?
    let reservable: Bool?
    let serves_breakfast: Bool?
    let serves_lunch: Bool?
    let serves_dinner: Bool?
    let source: String?
    let updated_at: String?
    let is_custom: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, city, description, location, geohash, rating, rating_count, price_level
        case categories, phone, website, menu_url, instagram, twitter, google_places_id, mapbox_id
        case fid, cid, thumbnail_url, photo_urls, open_hours, reservable
        case serves_breakfast, serves_lunch, serves_dinner, source, updated_at, is_custom
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        location = try container.decodeIfPresent(LocationData.self, forKey: .location)
        geohash = try container.decodeIfPresent(String.self, forKey: .geohash)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        rating_count = try container.decodeIfPresent(Int.self, forKey: .rating_count)
        price_level = try container.decodeIfPresent(String.self, forKey: .price_level)
        categories = try container.decodeIfPresent([String].self, forKey: .categories)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        menu_url = try container.decodeIfPresent(String.self, forKey: .menu_url)
        instagram = try container.decodeIfPresent(String.self, forKey: .instagram)
        twitter = try container.decodeIfPresent(String.self, forKey: .twitter)
        google_places_id = try container.decodeIfPresent(String.self, forKey: .google_places_id)
        mapbox_id = try container.decodeIfPresent(String.self, forKey: .mapbox_id)
        fid = try container.decodeIfPresent(String.self, forKey: .fid)
        cid = try container.decodeIfPresent(String.self, forKey: .cid)
        thumbnail_url = try container.decodeIfPresent(String.self, forKey: .thumbnail_url)
        photo_urls = try container.decodeIfPresent([String].self, forKey: .photo_urls)
        reservable = try container.decodeIfPresent(Bool.self, forKey: .reservable)
        serves_breakfast = try container.decodeIfPresent(Bool.self, forKey: .serves_breakfast)
        serves_lunch = try container.decodeIfPresent(Bool.self, forKey: .serves_lunch)
        serves_dinner = try container.decodeIfPresent(Bool.self, forKey: .serves_dinner)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
        is_custom = try container.decodeIfPresent(Bool.self, forKey: .is_custom)
        
        // Handle open_hours as jsonb - can be any JSON structure
        open_hours = try container.decodeIfPresent(AnyCodable.self, forKey: .open_hours)
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
    let name: String
    let coordinate: LocationData? // PostGIS geometry as custom struct (same as PlaceRecord)
}

struct PlaceListItemRecord: Codable {
    let place_id: String
    let list_id: String
    let sort_order: Int?
}

