import Foundation

/// Legacy PlaceService - now delegates all calls to SupabasePlaceService
/// This wrapper exists for backward compatibility with existing ViewModels
class PlaceService: ObservableObject {
    static let shared = PlaceService()
    private let supabase = SupabasePlaceService.shared // All data comes from Supabase
    
    private init() {
        print("⚠️ PlaceService is a compatibility wrapper - all data from Supabase")
    }

    // Async version of fetchAllPlaces
    func fetchAllPlaces() async throws -> [DetailPlace] {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        print("🔄 [PlaceService] Delegating to Supabase...")
        return try await supabase.fetchAllPlaces()
    }

    // Fetch all places from Supabase (was Firestore)
    func fetchAllPlaces(completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        print("🔄 [PlaceService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.fetchAllPlaces(completion: completion)
        }
    }

    func findPlace(mapboxId: String, completion: @escaping (DetailPlace?, Error?) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        print("🔄 [PlaceService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.findPlace(mapboxId: mapboxId, completion: completion)
        }
    }
    
    func fetchPlace(withId placeId: String, completion: @escaping (Result<DetailPlace, Error>) -> Void) {
        // ⚠️ NOW FETCHING FROM SUPABASE, NOT FIRESTORE
        print("🔄 [PlaceService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.fetchPlace(withId: placeId, completion: completion)
        }
    }
    
    func fetchPlace(withId placeId: String) async throws -> DetailPlace {
        print("🔄 [PlaceService] Delegating to Supabase (async)...")
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                await supabase.fetchPlace(withId: placeId) { result in
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
        print("🔄 [PlaceService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.addFavorite(userId: userId, placeId: placeId, completion: completion)
        }
    }
    
    func removeFavorite(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        print("🔄 [PlaceService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.removeFavorite(userId: userId, placeId: placeId, completion: completion)
        }
    }
    
    func fetchFavorites(userId: String, completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        print("🔄 [PlaceService] Delegating to Supabase...")
        Task { @MainActor in
            await supabase.fetchFavorites(userId: userId, completion: completion)
        }
    }
    
    func getDetailPlace(mapboxId: String, completion: @escaping (DetailPlace?) -> Void) {
        print("🔄 [PlaceService] Delegating to Supabase...")
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
        print("🔄 [PlaceService] Delegating fetchMyPlaces to Supabase...")
        Task { @MainActor in
            await supabase.fetchMyPlaces(userId: userId) { places, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(places ?? []))
                }
            }
        }
    }
    
    func fetchMyPlaces(userId: String) async throws -> [DetailPlace] {
        print("🔄 [PlaceService] Delegating fetchMyPlaces async to Supabase...")
        return try await supabase.fetchMyPlaces(userId: userId)
    }
    
    func fetchProfileFavorites(userId: String, completion: @escaping ([DetailPlace], Error?) -> Void) {
        print("🔄 [PlaceService] Delegating fetchProfileFavorites to Supabase...")
        Task { @MainActor in
            await supabase.fetchProfileFavorites(userId: userId) { places, error in
                completion(places ?? [], error)
            }
        }
    }

    func fetchProfileFavorites(userId: String) async throws -> [DetailPlace] {
        print("🔄 [PlaceService] Delegating fetchProfileFavorites async to Supabase...")
        return try await supabase.fetchProfileFavorites(userId: userId)
    }
    
    func fetchLists(userId: String, completion: @escaping ([PlaceList]) -> Void) {
        print("🔄 [PlaceService] Delegating fetchLists to Supabase...")
        Task { @MainActor in
            await supabase.fetchLists(userId: userId, completion: completion)
        }
    }

    func fetchLists(userId: String) async throws -> [PlaceList] {
        print("🔄 [PlaceService] Delegating fetchLists async to Supabase...")
        return try await supabase.fetchLists(userId: userId)
    }
    
    func fetchPlacesInViewport(viewport: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double), completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        print("🔄 [PlaceService] Delegating fetchPlacesInViewport to Supabase...")
        Task { @MainActor in
            guard let userId = await SupabaseAuthService.shared.currentUserId else {
                print("⚠️ [PlaceService] No userId available for viewport query")
                completion([], nil)
                return
            }
            await supabase.fetchPlacesInViewport(
                northLat: viewport.maxLat,
                southLat: viewport.minLat,
                eastLng: viewport.maxLng,
                westLng: viewport.minLng,
                userId: userId,
                completion: completion
            )
        }
    }
    
    func fetchPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double) async throws -> [DetailPlace] {
        print("🔄 [PlaceService] Delegating fetchPlacesInViewport async to Supabase...")
        guard let userId = await SupabaseAuthService.shared.currentUserId else {
            print("⚠️ [PlaceService] No userId available for viewport query")
            return []
        }
        return try await supabase.fetchPlacesInViewport(
            northLat: northLat,
            southLat: southLat,
            eastLng: eastLng,
            westLng: westLng,
            userId: userId
        )
    }
    
    func fetchFriendsPlacesInViewport(viewport: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double), friendIds: [String], completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        print("🔄 [PlaceService] Delegating fetchFriendsPlacesInViewport to Supabase...")
        Task { @MainActor in
            do {
                var allPlaces: [DetailPlace] = []
                // Fetch places for each friend
                for friendId in friendIds {
                    let friendPlaces = try await supabase.fetchPlacesInViewport(
                        northLat: viewport.maxLat,
                        southLat: viewport.minLat,
                        eastLng: viewport.maxLng,
                        westLng: viewport.minLng,
                        userId: friendId
                    )
                    allPlaces.append(contentsOf: friendPlaces)
                }
                // Remove duplicates by place ID
                let uniquePlaces = Dictionary(grouping: allPlaces, by: { $0.id })
                    .compactMap { $0.value.first }
                completion(uniquePlaces, nil)
            } catch {
                print("❌ [PlaceService] Error fetching friends' viewport places: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func fetchFriendsPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, friendIds: [String]) async throws -> [DetailPlace] {
        print("🔄 [PlaceService] Delegating fetchFriendsPlacesInViewport async to Supabase...")
        var allPlaces: [DetailPlace] = []
        // Fetch places for each friend
        for friendId in friendIds {
            let friendPlaces = try await supabase.fetchPlacesInViewport(
                northLat: northLat,
                southLat: southLat,
                eastLng: eastLng,
                westLng: westLng,
                userId: friendId
            )
            allPlaces.append(contentsOf: friendPlaces)
        }
        // Remove duplicates by place ID
        let uniquePlaces = Dictionary(grouping: allPlaces, by: { $0.id })
            .compactMap { $0.value.first }
        return uniquePlaces
    }
    
    func addToAllPlaces(place: DetailPlace, completion: @escaping (Error?) -> Void) {
        print("⚠️ [PlaceService] addToAllPlaces not fully implemented")
        completion(nil)
    }
    
    func addToMyPlaces(userId: String, place: DetailPlace, completion: @escaping (Error?) -> Void) {
        print("⚠️ [PlaceService] addToMyPlaces not fully implemented")
        completion(nil)
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
    
    func updatePlace(place: DetailPlace, completion: @escaping (Error?) -> Void) {
        print("⚠️ [PlaceService] updatePlace not fully implemented")
        completion(nil)
    }
    
    func createNewList(userId: String, listName: String, city: String, emoji: String, image: String, completion: @escaping (PlaceList?, Error?) -> Void) {
        print("⚠️ [PlaceService] createNewList not fully implemented")
        let newList = PlaceList(name: listName, city: city, emoji: emoji, image: image)
        completion(newList, nil)
    }
    
    func deleteList(userId: String, listId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [PlaceService] deleteList not fully implemented")
        completion(nil)
    }
    
    func deletePlaceFromMyPlaces(userId: String, placeId: String, completion: @escaping (Error?) -> Void) {
        print("⚠️ [PlaceService] deletePlaceFromMyPlaces not fully implemented")
        completion(nil)
    }
    
    func deletePlaceFromAllPlaces(placeId: String) async throws {
        print("⚠️ [PlaceService] deletePlaceFromAllPlaces not fully implemented")
        // TODO: Implement with Supabase
    }
}
