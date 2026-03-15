import Foundation
import CoreLocation

/// Legacy PlaceService - now delegates all calls to SupabasePlaceService
/// This wrapper exists for backward compatibility with existing ViewModels
class PlaceService: ObservableObject {
    nonisolated(unsafe) static let shared = PlaceService()
    private let supabase = SupabasePlaceService.shared // All data comes from Supabase
    
    private init() {
        // PlaceService is a compatibility wrapper - all data from Supabase
    }

    // Async version of fetchAllPlaces
    func fetchAllPlaces() async throws -> [DetailPlace] {
        return try await supabase.fetchAllPlaces()
    }

    func fetchAllPlaces(completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        Task { @MainActor in
            supabase.fetchAllPlaces(completion: completion)
        }
    }

    func findPlace(mapboxId: String, completion: @escaping (DetailPlace?, Error?) -> Void) {
        Task { @MainActor in
            supabase.findPlace(mapboxId: mapboxId, completion: completion)
        }
    }
    
    func fetchPlace(withId placeId: String, completion: @escaping (Result<DetailPlace, Error>) -> Void) {
        Task { @MainActor in
            supabase.fetchPlace(withId: placeId, completion: completion)
        }
    }
    
    func fetchPlace(withId placeId: String) async throws -> DetailPlace {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                supabase.fetchPlace(withId: placeId) { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    // Placeholder methods for compatibility
    func addPlaceToList(userId: String, listName: String, place: Place) {
        print("⚠️ [PlaceService] addPlaceToList not fully implemented")
    }
    
    func addFavorite(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            supabase.addFavorite(userId: userId, placeId: placeId, completion: completion)
        }
    }
    
    func removeFavorite(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            supabase.removeFavorite(userId: userId, placeId: placeId, completion: completion)
        }
    }
    
    func fetchFavorites(userId: String, completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        Task { @MainActor in
            supabase.fetchFavorites(userId: userId, completion: completion)
        }
    }
    
    func getDetailPlace(mapboxId: String, completion: @escaping (DetailPlace?) -> Void) {
        findPlace(mapboxId: mapboxId) { place, error in
            if let error = error {
                print("❌ Error fetching place: \(error)")
                completion(nil)
                } else {
                completion(place)
            }
        }
    }
    
    /// Fetch ALL user places in a single optimized query (fastest!)
    /// Includes my_places, favorites, and all place_list_items
    func fetchAllUserPlaces(userId: String) async throws -> [DetailPlace] {
        print("🚀 [PlaceService] Delegating fetchAllUserPlaces to Supabase...")
        return try await supabase.fetchAllUserPlaces(userId: userId)
    }
    
    func fetchMyPlaces(userId: String, completion: @escaping (Result<[DetailPlace], Error>) -> Void) {
        Task { @MainActor in
            supabase.fetchMyPlaces(userId: userId) { places, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(places ?? []))
                }
            }
        }
    }
    
    func fetchMyPlaces(userId: String) async throws -> [DetailPlace] {
        return try await supabase.fetchMyPlaces(userId: userId)
    }
    
    func fetchProfileFavorites(userId: String, completion: @escaping ([DetailPlace], Error?) -> Void) {
        Task { @MainActor in
            supabase.fetchProfileFavorites(userId: userId) { places, error in
                completion(places ?? [], error)
            }
        }
    }

    func fetchProfileFavorites(userId: String) async throws -> [DetailPlace] {
        return try await supabase.fetchProfileFavorites(userId: userId)
    }
    
    func fetchLists(userId: String, completion: @escaping ([PlaceList]) -> Void) {
        Task { @MainActor in
            supabase.fetchLists(userId: userId, completion: completion)
        }
    }

    func fetchLists(userId: String) async throws -> [PlaceList] {
        return try await supabase.fetchLists(userId: userId)
    }
    
    /// ✅ NEW: Fetch favorite place IDs only (not full place documents) - SUPER FAST!
    func fetchFavoritePlaceIds(userId: String) async throws -> [String] {
        return try await supabase.fetchFavoritePlaceIds(userId: userId)
    }
    
    /// ✅ NEW: Fetch my place IDs only (not full place documents) - SUPER FAST!
    func fetchMyPlaceIds(userId: String) async throws -> [String] {
        return try await supabase.fetchMyPlaceIds(userId: userId)
    }
    
    /// ✅ NEW: Fetch list metadata only (not full place documents) - SUPER FAST!
    func fetchListMetadata(userId: String) async throws -> [PlaceList] {
        return try await supabase.fetchListMetadata(userId: userId)
    }
    
    /// Fetches place lists sorted by proximity to user's current location
    func fetchListsByProximity(userId: String, userLocation: CLLocationCoordinate2D?, completion: @escaping ([PlaceList]) -> Void) {
        Task { @MainActor in
            supabase.fetchListsByProximity(userId: userId, userLocation: userLocation, completion: completion)
        }
    }
    
    /// Async version: Fetches place lists sorted by proximity to user's current location
    func fetchListsByProximity(userId: String, userLocation: CLLocationCoordinate2D?) async throws -> [PlaceList] {
        return try await supabase.fetchListsByProximity(userId: userId, userLocation: userLocation)
    }
    
    /// Fetch places for multiple lists efficiently (for first 6 visible lists)
    func fetchPlacesForLists(listIds: [String], maxPlacesPerList: Int = 6) async throws -> [String: [DetailPlace]] {
        return try await supabase.fetchPlacesForLists(listIds: listIds, maxPlacesPerList: maxPlacesPerList)
    }
    
    /// Get place count for multiple lists efficiently
    func getPlaceCountsForLists(listIds: [String]) async throws -> [String: Int] {
        return try await supabase.getPlaceCountsForLists(listIds: listIds)
    }
    
    func fetchPlacesInViewport(viewport: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double), completion: @escaping ([PlaceAnnotation]?, Error?) -> Void) {
        Task { @MainActor in
            guard let authUserId = SupabaseAuthService.shared.currentUserId else {
                print("⚠️ [PlaceService] No auth userId available for viewport query")
                completion([], nil)
                return
            }
            
            // Get the profile user ID (not auth UID)
            let profileUserId: String
            do {
                let profile = try await UserService.shared.fetchUserById(userId: authUserId)
                profileUserId = profile.id
            } catch {
                print("⚠️ [PlaceService] Could not fetch profile, using auth UID as fallback: \(authUserId)")
                profileUserId = authUserId
            }
            
            supabase.fetchPlacesInViewport(
                northLat: viewport.maxLat,
                southLat: viewport.minLat,
                eastLng: viewport.maxLng,
                westLng: viewport.minLng,
                userId: profileUserId,
                completion: completion
            )
        }
    }
    
    func fetchPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double) async throws -> [PlaceAnnotation] {
        guard let authUserId = await SupabaseAuthService.shared.currentUserId else {
            return []
        }
        
        // Get the profile user ID (not auth UID)
        let profileUserId: String
        do {
            let profile = try await UserService.shared.fetchUserById(userId: authUserId)
            profileUserId = profile.id
        } catch {
            print("⚠️ [PlaceService] Could not fetch profile, using auth UID as fallback: \(authUserId)")
            profileUserId = authUserId
        }
        
        return try await supabase.fetchPlacesInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: profileUserId
        )
    }
    
    /// Fetch full place details on demand (when user taps a marker)
    func fetchPlaceDetails(placeId: String) async throws -> DetailPlace? {
        return try await supabase.fetchPlaceDetails(placeId: placeId)
    }
    
    /// Batch fetch full place details for multiple places
    func fetchPlaceDetailsBatch(placeIds: [String]) async throws -> [DetailPlace] {
        return try await supabase.fetchPlaceDetailsBatch(placeIds: placeIds)
    }
    
    /// Fetch profile photos for all followed users (for custom annotation views)
    func fetchFollowedUsersPhotos(userId: String) async throws -> [FollowedUserPhoto] {
        return try await supabase.fetchFollowedUsersPhotos(userId: userId)
    }
    
    /// ✅ NEW: Fetch places in viewport with explicit user ID (for DataManager)
    func fetchPlacesInViewportWithUserId(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [PlaceAnnotation] {
        return try await supabase.fetchPlacesInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }
    
    /// Fetches map annotations for a specific place list
    func fetchListAnnotationsInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String, listId: String) async throws -> [PlaceAnnotation] {
        return try await supabase.fetchListAnnotationsInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId,
            listId: listId
        )
    }

    /// Fetches map annotations for user's external places
    func fetchExternalAnnotationsInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [PlaceAnnotation] {
        return try await supabase.fetchExternalAnnotationsInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }

    /// Fetches map annotations for user's reviewed places
    func fetchReviewAnnotationsInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [PlaceAnnotation] {
        return try await supabase.fetchReviewAnnotationsInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }

    /// Fetches map annotations for user's favorite places
    func fetchFavoriteAnnotationsInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [PlaceAnnotation] {
        return try await supabase.fetchFavoriteAnnotationsInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }

    /// Fetches map annotations for user's created places (my places)
    func fetchMyPlacesAnnotationsInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [PlaceAnnotation] {
        return try await supabase.fetchMyPlacesAnnotationsInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }

    /// Fetches map annotations for keyword search results with user_ids from save sources
    func fetchKeywordAnnotationsInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, types: [String], userId: String) async throws -> [PlaceAnnotation] {
        return try await supabase.fetchKeywordAnnotationsInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            types: types,
            userId: userId
        )
    }

    /// Fetch community places in viewport - places saved by users outside your network
    /// Returns lightweight emoji markers using grid-based clustering for O(n) performance
    /// Note: Prefer `fetchCommunityPlacesInViewportWithUserId` when caller already has user ID
    func fetchCommunityPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double) async throws -> [CommunityPlaceMarker] {
        guard let authUserId = await SupabaseAuthService.shared.currentUserId else {
            return []
        }
        
        // Get the profile user ID (not auth UID)
        let profileUserId: String
        do {
            let profile = try await UserService.shared.fetchUserById(userId: authUserId)
            profileUserId = profile.id
        } catch {
            print("⚠️ [PlaceService] Could not fetch profile, using auth UID as fallback: \(authUserId)")
            profileUserId = authUserId
        }
        
        return try await supabase.fetchCommunityPlacesInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: profileUserId
        )
    }
    
    /// ✅ Fetch community places with explicit user ID (avoids redundant profile lookups)
    /// Use this when caller already has the profile user ID from ProfileViewModel
    func fetchCommunityPlacesInViewportWithUserId(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [CommunityPlaceMarker] {
        return try await supabase.fetchCommunityPlacesInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }
    
    /// Fetch ALL friends places in viewport WITHOUT density filtering
    /// Used for "Places in View" popup to show every place regardless of zoom level
    func fetchAllFriendsPlacesInViewportWithUserId(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [PlaceAnnotation] {
        return try await supabase.fetchAllFriendsPlacesInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }
    
    /// Fetch ALL community places in viewport WITHOUT density filtering
    /// Used for "Places in View" popup to show every place regardless of zoom level
    func fetchAllCommunityPlacesInViewportWithUserId(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, userId: String) async throws -> [CommunityPlaceMarker] {
        return try await supabase.fetchAllCommunityPlacesInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }
    
    // fetchFriendsPlacesInViewport methods removed - the main get_visible_annotations_with_users function
    // now handles both user and friends' places in a single optimized query
    
    func addToAllPlaces(place: DetailPlace, completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            SupabasePlaceService.shared.addToAllPlaces(place: place, completion: completion)
        }
    }
    
    /// Ensures a place exists in the database (upsert - insert if not exists)
    /// Call this before creating posts to satisfy foreign key constraints
    func ensurePlaceExists(place: DetailPlace) async throws {
        try await SupabasePlaceService.shared.ensurePlaceExists(place: place)
    }
    
    func addToMyPlaces(userId: String, place: DetailPlace, completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            SupabasePlaceService.shared.addToMyPlaces(userId: userId, place: place, completion: completion)
        }
    }
    
    func fetchList(userId: String, listId: String, completion: @escaping (Result<PlaceList, Error>) -> Void) {
        print("⚠️ [PlaceService] fetchList not fully implemented")
        completion(.failure(NSError(domain: "PlaceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))
    }
    
    func addPhotosToPlace(placeId: String, photoURLs: [String], completion: @escaping (Error?) -> Void) {
        print("⚠️ [PlaceService] addPhotosToPlace not fully implemented")
        completion(nil)
    }
    
    func removePlaceFromList(userId: String, listId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [PlaceService] removePlaceFromList not fully implemented")
        completion(nil)
    }
    
    func createNewList(userId: String, listName: String, city: String, emoji: String, image: String, completion: @escaping (PlaceList?, Error?) -> Void) {
        Task { @MainActor in
            do {
                let createdList = try await SupabasePlaceService.shared.createNewList(
                    userId: userId,
                    name: listName,
                    city: city,
                    emoji: emoji,
                    image: image
                )
                completion(createdList, nil)
            } catch {
                print("❌ [PlaceService] Error creating new list: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func deleteList(userId: String, listId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [PlaceService] deleteList not fully implemented")
        completion(nil)
    }
    
    func deletePlaceFromMyPlaces(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            SupabasePlaceService.shared.deletePlaceFromMyPlaces(userId: userId, placeId: placeId, completion: completion)
        }
    }
    
    func deletePlaceFromAllPlaces(placeId: String, completion: @escaping (Error?) -> Void) {
        Task { @MainActor in
            SupabasePlaceService.shared.deletePlaceFromAllPlaces(placeId: placeId, completion: completion)
        }
    }
    
    // MARK: - Custom Place Creator
    
    /// Fetch the creator of a custom place
    /// Returns nil if the place is not a custom place or has no creator
    func fetchCustomPlaceCreator(placeId: String) async throws -> CustomPlaceCreator? {
        return try await supabase.fetchCustomPlaceCreator(placeId: placeId)
    }

    // MARK: - City Annotations

    /// Fetches city-level annotations aggregating places by city within the viewport.
    func fetchCityAnnotationsInViewport(
        northLat: Double,
        southLat: Double,
        eastLng: Double,
        westLng: Double,
        userId: String
    ) async throws -> [CityAnnotation] {
        return try await supabase.fetchCityAnnotationsInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }

    /// Fetches lists with places near a city coordinate.
    func fetchCityDetailLists(userId: String, latitude: Double, longitude: Double) async throws -> [CityDetailListRecord] {
        return try await supabase.fetchCityDetailLists(userId: userId, latitude: latitude, longitude: longitude)
    }

    /// Fetches top places near a city coordinate.
    func fetchCityTopPlaces(userId: String, latitude: Double, longitude: Double) async throws -> [CityTopPlace] {
        return try await supabase.fetchCityTopPlaces(userId: userId, latitude: latitude, longitude: longitude)
    }

    /// Fetches TikTok videos saved to places near a city coordinate with pagination.
    func fetchCityTiktoks(userId: String, latitude: Double, longitude: Double, limit: Int = 20, offset: Int = 0) async throws -> [CityTikTok] {
        return try await supabase.fetchCityTiktoks(userId: userId, latitude: latitude, longitude: longitude, limit: limit, offset: offset)
    }

    /// Fetches users who have saved places near a city coordinate.
    func fetchCityActiveUsers(userId: String, latitude: Double, longitude: Double) async throws -> [CityActiveUser] {
        return try await supabase.fetchCityActiveUsers(userId: userId, latitude: latitude, longitude: longitude)
    }

    /// Fetches review photos from places near a city coordinate with pagination.
    func fetchCityReviewPhotos(userId: String, latitude: Double, longitude: Double, limit: Int = 20, offset: Int = 0) async throws -> [CityReviewPhoto] {
        return try await supabase.fetchCityReviewPhotos(userId: userId, latitude: latitude, longitude: longitude, limit: limit, offset: offset)
    }

    /// Searches for cities matching a query within the user's social graph.
    func searchCities(userId: String, query: String) async throws -> [CitySearchResult] {
        return try await supabase.searchCities(userId: userId, query: query)
    }
}
