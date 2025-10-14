//
//  SupabasePlaceService.swift
//  loc
//
//  Place service using Supabase (replacement for Firebase PlaceService)
//

import Foundation
import Supabase
import CoreLocation
import FirebaseFirestore

@MainActor
class SupabasePlaceService: ObservableObject {
    static let shared = SupabasePlaceService()
    private let supabase = SupabaseManager.shared
    
    private init() {}

    // MARK: - PlaceList Records

    struct PlaceListRecord: Codable {
        let id: String
        let user_id: String
        let name: String
        let description: String?
        let cover_image_url: String?
        let is_public: Bool
        let sort_order: Int

        enum CodingKeys: String, CodingKey {
            case id
            case user_id
            case name
            case description
            case cover_image_url
            case is_public
            case sort_order
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
        
        // Handle coordinate from PostGIS geometry
        if let locationString = record.location_text {
            // Try to parse the GeoJSON format or raw coordinates
            // Format example: {"type":"Point","coordinates":[-122.4,37.8]}
            if let data = locationString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let coords = json["coordinates"] as? [Double], coords.count >= 2 {
                place.coordinate = GeoPoint(latitude: coords[1], longitude: coords[0])
            }
        }
        
        return place
    }

    // MARK: - Fetch Place Lists

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
                for (index, record) in records.enumerated() {
                    print("🔍 [Supabase] Record \(index + 1): id=\(record.id), name=\(record.name), user_id=\(record.user_id)")
                }

                let placeLists = records.map { record in
                    PlaceList(
                        id: UUID(uuidString: record.id) ?? UUID(),
                        name: record.name,
                        places: [], // TODO: Fetch actual places in list
                        city: "", // TODO: Calculate from places in list
                        emoji: "📍", // Default emoji
                        image: record.cover_image_url,
                        sortOrder: record.sort_order,
                        averageCoordinate: nil,
                        lastCoordinateUpdate: nil
                    )
                }

                print("✅ [Supabase] Fetched \(placeLists.count) place lists for user: \(userId)")
                
                // Log each place list with details
                for (index, list) in placeLists.enumerated() {
                    print("📋 [Supabase] Place List \(index + 1):")
                    print("   - ID: \(list.id)")
                    print("   - Name: \(list.name)")
                    print("   - Sort Order: \(list.sortOrder)")
                    print("   - Cover Image: \(list.image ?? "nil")")
                    print("   - Places Count: \(list.places.count)")
                    print("   - City: \(list.city)")
                    print("   - Emoji: \(list.emoji)")
                }
                
                completion(placeLists)

            } catch {
                print("❌ [Supabase] Error fetching place lists: \(error)")
                completion([])
            }
        }
    }

    func fetchLists(userId: String) async throws -> [PlaceList] {
        print("📋 [Supabase] Fetching place lists for user: \(userId)")

        do {
            print("🔍 [Supabase] Querying place_lists for user_id: \(userId)")
            print("🔍 [Supabase] User ID type: \(type(of: userId))")
            print("🔍 [Supabase] User ID length: \(userId.count)")
            print("🔍 [Supabase] User ID characters: \(Array(userId))")
            print("🔍 [Supabase] Using Supabase client for database queries")
            print("🔍 [Supabase] Supabase URL from config: \(SupabaseConfig.supabaseURL)")
            print("🔍 [Supabase] Project ref: \(SupabaseConfig.supabaseURL.lastPathComponent)")
            
            // Check authentication status
            do {
                let session = try await supabase.client.auth.session
                print("🔍 [Supabase] Auth session exists: true")
                print("🔍 [Supabase] Auth user ID: \(session.user.id)")
                print("🔍 [Supabase] Auth user email: \(session.user.email ?? "nil")")
            } catch {
                print("❌ [Supabase] No auth session: \(error)")
            }
            
            // First, let's test if we can query the table at all
            do {
                let allRecords: [PlaceListRecord] = try await supabase.client
                    .from("place_lists")
                    .select()
                    .limit(5)
                    .execute()
                    .value
                
                print("🔍 [Supabase] Test query - found \(allRecords.count) total records in place_lists table")
                for (index, record) in allRecords.enumerated() {
                    print("🔍 [Supabase] Test record \(index + 1): id=\(record.id), name=\(record.name), user_id=\(record.user_id)")
                }
            } catch {
                print("❌ [Supabase] Error accessing place_lists table: \(error)")
                print("❌ [Supabase] Error details: \(error.localizedDescription)")
                if let supabaseError = error as? PostgrestError {
                    print("❌ [Supabase] PostgrestError: \(supabaseError)")
                }
            }
            
            // Let's also test if we can access the users table
            do {
                let userRecords: [ProfileData] = try await supabase.client
                    .from("users")
                    .select()
                    .limit(3)
                    .execute()
                    .value
                print("🔍 [Supabase] Test query - found \(userRecords.count) total records in users table")
                for (index, user) in userRecords.enumerated() {
                    print("🔍 [Supabase] Test user \(index + 1): id=\(user.id), name=\(user.firstName) \(user.lastName)")
                }
            } catch {
                print("❌ [Supabase] Error accessing users table: \(error)")
            }
            
            // Let's check if there are any other tables that might contain place lists
            print("🔍 [Supabase] Checking for alternative table names...")
            let alternativeTableNames = ["lists", "user_lists", "places", "user_places", "collections"]
            
            for tableName in alternativeTableNames {
                do {
                    let testRecords: [PlaceListRecord] = try await supabase.client
                        .from(tableName)
                        .select()
                        .limit(1)
                        .execute()
                        .value
                    print("🔍 [Supabase] Found \(testRecords.count) records in '\(tableName)' table")
                } catch {
                    print("🔍 [Supabase] Table '\(tableName)' not found or not accessible")
                }
            }
            
            // Try querying with the profile user ID first
            var records: [PlaceListRecord] = try await supabase.client
                .from("place_lists")
                .select()
                .eq("user_id", value: userId)
                .order("sort_order", ascending: true)
                .execute()
                .value
            
            print("🔍 [Supabase] Query with profile user ID returned: \(records.count) records")
            
            // If no records found, try with the Supabase auth user ID
            if records.isEmpty {
                do {
                    let session = try await supabase.client.auth.session
                    let authUserId = session.user.id.uuidString
                    print("🔍 [Supabase] Trying query with auth user ID: \(authUserId)")
                    
                    records = try await supabase.client
                        .from("place_lists")
                        .select()
                        .eq("user_id", value: authUserId)
                        .order("sort_order", ascending: true)
                        .execute()
                        .value
                    
                    print("🔍 [Supabase] Query with auth user ID returned: \(records.count) records")
                } catch {
                    print("❌ [Supabase] Error getting auth session for fallback query: \(error)")
                }
            }

            print("🔍 [Supabase] Raw database response: \(records.count) records")
            for (index, record) in records.enumerated() {
                print("🔍 [Supabase] Record \(index + 1): id=\(record.id), name=\(record.name), user_id=\(record.user_id)")
            }

            let placeLists = records.map { record in
                PlaceList(
                    id: UUID(uuidString: record.id) ?? UUID(),
                    name: record.name,
                    places: [], // TODO: Fetch actual places in list
                    city: "", // TODO: Calculate from places in list
                    emoji: "📍", // Default emoji
                    image: record.cover_image_url,
                    sortOrder: record.sort_order,
                    averageCoordinate: nil,
                    lastCoordinateUpdate: nil
                )
            }

            print("✅ [Supabase] Fetched \(placeLists.count) place lists")
            
            // Log each place list with details
            for (index, list) in placeLists.enumerated() {
                print("📋 [Supabase] Place List \(index + 1):")
                print("   - ID: \(list.id)")
                print("   - Name: \(list.name)")
                print("   - Sort Order: \(list.sortOrder)")
                print("   - Cover Image: \(list.image ?? "nil")")
                print("   - Places Count: \(list.places.count)")
                print("   - City: \(list.city)")
                print("   - Emoji: \(list.emoji)")
            }
            
            return placeLists

        } catch {
            print("❌ [Supabase] Error fetching place lists: \(error)")
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
    let location_text: String? // PostGIS geometry as text/GeoJSON string
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, address, city, mapbox_id
        case location_text = "location"
        case categories, phone, rating
        case user_ratings_total, open_hours, description_text, price_level, reservable
        case serves_breakfast, serves_lunch, serves_dinner, instagram, x, photo_urls
        case google_place_id, source, created_at
    }
}

struct FavoriteRecord: Codable {
    let user_id: String
    let place_id: String
}

