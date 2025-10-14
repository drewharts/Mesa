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
    
    func fetchMyPlaces(userId: String, completion: @escaping (Result<[DetailPlace], Error>) -> Void) {
        print("⚠️ [PlaceService] fetchMyPlaces not fully implemented")
        completion(.success([]))
    }
    
    func fetchMyPlaces(userId: String) async throws -> [DetailPlace] {
        print("⚠️ [PlaceService] fetchMyPlaces async not fully implemented")
        return []
    }
    
    func fetchProfileFavorites(userId: String, completion: @escaping ([DetailPlace], Error?) -> Void) {
        print("⚠️ [PlaceService] fetchProfileFavorites not fully implemented")
        completion([], nil)
    }

    func fetchProfileFavorites(userId: String) async throws -> [DetailPlace] {
        print("⚠️ [PlaceService] fetchProfileFavorites async not fully implemented")
        return []
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
        print("⚠️ [PlaceService] fetchPlacesInViewport not fully implemented")
        completion([], nil)
    }
    
    func fetchPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double) async throws -> [DetailPlace] {
        print("⚠️ [PlaceService] fetchPlacesInViewport async not fully implemented")
        return []
    }
    
    func fetchFriendsPlacesInViewport(viewport: (minLat: Double, maxLat: Double, minLng: Double, maxLng: Double), friendIds: [String], completion: @escaping ([DetailPlace]?, Error?) -> Void) {
        print("⚠️ [PlaceService] fetchFriendsPlacesInViewport not fully implemented")
        completion([], nil)
    }
    
    func fetchFriendsPlacesInViewport(northLat: Double, southLat: Double, eastLng: Double, westLng: Double, friendIds: [String]) async throws -> [DetailPlace] {
        print("⚠️ [PlaceService] fetchFriendsPlacesInViewport async not fully implemented")
        return []
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
