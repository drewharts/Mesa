import Foundation
import CoreLocation
import FirebaseFirestore
import MapboxSearch

// MARK: - Search Service Protocols

/// Protocol for place search suggestions
protocol PlaceSuggestion: Identifiable {
    var id: String { get }
    var name: String { get }
    var address: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
}

/// Protocol for place search results
protocol PlaceResult: Identifiable {
    var id: String { get }
    var name: String { get }
    var address: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
}

// MARK: - Mesa Backend Models

/// Model for location data in Mesa backend responses
struct MesaLocation: Codable {
    let latitude: Double
    let longitude: Double
}

/// Model for Google address components
struct GoogleAddressComponent: Codable {
    let long_name: String
    let short_name: String
    let types: [String]
}

/// Model for Google geometry
struct GoogleGeometry: Codable {
    let location: MesaLocation
    let viewport: GoogleViewport
}

/// Model for Google viewport
struct GoogleViewport: Codable {
    let northeast: MesaLocation
    let southwest: MesaLocation
}

/// Model for Google opening hours period
struct GoogleOpeningHoursPeriod: Codable {
    let close: GoogleTime
    let open: GoogleTime
}

/// Model for Google time
struct GoogleTime: Codable {
    let day: Int
    let time: String
}

/// Model for Google opening hours
struct GoogleOpeningHours: Codable {
    let open_now: Bool
    let periods: [GoogleOpeningHoursPeriod]
    let weekday_text: [String]
}

/// Model for Google place details
struct GooglePlaceDetails: Codable {
    let address_components: [GoogleAddressComponent]
    let business_status: String
    let city: String
    let formatted_address: String
    let geometry: GoogleGeometry
    let name: String
    let opening_hours: GoogleOpeningHours?
    let place_id: String
    let rating: Double?
    let types: [String]
    let website: String?
}

/// Model for place details from Mesa backend
struct MesaPlaceDetails: Codable {
    let additional_data: [String: String]
    let address: String
    let id: String
    let location: MesaLocation
    let name: String
    let provider: String
}

/// Response model for Mesa backend place details endpoint
struct MesaPlaceDetailsResponse: Codable {
    let place: MesaPlaceDetails
}

/// Model for suggestion data from Mesa backend
struct MesaSuggestion: Codable, Identifiable {
    let address: String
    let id: String
    let location: MesaLocation
    let name: String
    let source: String
}

/// Response model for Mesa backend suggestions endpoint
struct MesaSuggestionsResponse: Codable {
    let suggestions: [MesaSuggestion]
}

// MARK: - Place Suggestion and Result Models

/// Mesa implementation of PlaceSuggestion
struct MesaPlaceSuggestion: PlaceSuggestion {
    let id: String
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let source: String
}

/// Mesa implementation of PlaceResult
struct MesaPlaceResult: PlaceResult {
    let id: String
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let source: String
    let additional_data: [String: String]
}

// MARK: - Mesa Backend Service

/// Service class for the Mesa backend API
class MesaBackendService {
    private let baseURL = "https://mesa-backend-staging.up.railway.app"
    private let session = URLSession.shared
    
    /// Fetch place suggestions from Mesa backend
    func fetchSuggestions(
        query: String,
        limit: Int = 5,
        provider: String = "all",
        latitude: Double? = nil,
        longitude: Double? = nil,
        completion: @escaping (Result<[MesaPlaceSuggestion], Error>) -> Void
    ) {
        guard !query.isEmpty else {
            completion(.success([]))
            return
        }

        guard var urlComponents = URLComponents(string: "\(baseURL)/search/suggestions") else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        // Add query parameters
        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "provider", value: provider)
        ]

        // Add location parameters if provided
        if let latitude = latitude {
            queryItems.append(URLQueryItem(name: "latitude", value: String(latitude)))
        }
        if let longitude = longitude {
            queryItems.append(URLQueryItem(name: "longitude", value: String(longitude)))
        }

        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "MesaBackend", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(MesaSuggestionsResponse.self, from: data)
                
                let suggestions = response.suggestions.map { mesaSuggestion in
                    return MesaPlaceSuggestion(
                        id: mesaSuggestion.id,
                        name: mesaSuggestion.name,
                        address: mesaSuggestion.address,
                        coordinate: CLLocationCoordinate2D(
                            latitude: mesaSuggestion.location.latitude,
                            longitude: mesaSuggestion.location.longitude
                        ),
                        source: mesaSuggestion.source
                    )
                }
                
                completion(.success(suggestions))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Handle Google place details
    /// WARNING: This function appears to be unused/dead code
    private func handleGooglePlaceDetails(_ data: [String: Any]) -> DetailPlace {
        var additionalData: [String: String] = [:]
        
        // Extract opening hours if available
        if let openingHours = data["opening_hours"] as? [String: Any] {
            if let weekdayText = openingHours["weekday_text"] as? [String] {
                additionalData["weekday_text"] = weekdayText.joined(separator: "|")
            }
        }
        
        // Extract location data
        var latitude: Double = 0
        var longitude: Double = 0
        if let geometry = data["geometry"] as? [String: Any],
           let location = geometry["location"] as? [String: Any] {
            latitude = location["lat"] as? Double ?? 0
            longitude = location["lng"] as? Double ?? 0
        }
        
        // Create DetailPlace object
        var detailPlace = DetailPlace()
        // CRITICAL: This function should be updated to use backend-provided ID
        // For now, creating a new UUID but this is incorrect and will orphan places
        detailPlace.id = UUID()
        detailPlace.name = data["name"] as? String ?? ""
        detailPlace.address = data["formatted_address"] as? String
        detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
        detailPlace.rating = data["rating"] as? Double
        detailPlace.openHours = additionalData["weekday_text"]?.components(separatedBy: "|")
        detailPlace.priceLevel = data["price_level"] as? String
        detailPlace.categories = data["types"] as? [String]
        
        return detailPlace
    }
    
    /// Handle Mapbox place details
    /// WARNING: This function appears to be unused/dead code
    private func handleMapboxPlaceDetails(_ data: [String: Any]) -> DetailPlace {
        // Create DetailPlace object
        var detailPlace = DetailPlace()
        
        // Extract the additional_data which contains most of the fields
        if let additionalData = data["additional_data"] as? [String: Any] {
            // Set basic fields
            // CRITICAL: This function should be updated to use backend-provided ID
            // For now, creating a new UUID but this is incorrect and will orphan places
            detailPlace.id = UUID()
            detailPlace.name = additionalData["name"] as? String ?? ""
            detailPlace.address = additionalData["full_address"] as? String
            detailPlace.mapboxId = additionalData["mapbox_id"] as? String
            
            // Set city and region from context
            if let context = additionalData["context"] as? [String: Any],
               let place = context["place"] as? [String: Any] {
                detailPlace.city = place["name"] as? String
            }
            
            // Set categories from poi_category
            detailPlace.categories = additionalData["poi_category"] as? [String]
            
            // Set coordinate from coordinates
            if let coordinates = additionalData["coordinates"] as? [String: Any],
               let latitude = coordinates["latitude"] as? Double,
               let longitude = coordinates["longitude"] as? Double {
                detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
            }
            
            // Additional metadata fields are available but not currently used:
            // - metadata: additionalData["metadata"] as? [String: Any]
            // - feature_type: additionalData["feature_type"] as? String
            // - operational_status: additionalData["operational_status"] as? String
            // - maki: additionalData["maki"] as? String
            // - language: additionalData["language"] as? String
        }
        
        return detailPlace
    }
    
    /// Handle local place details
    /// WARNING: This function appears to be unused/dead code
    private func handleLocalPlaceDetails(_ data: [String: Any]) -> DetailPlace {
        // Create a new DetailPlace object
        var detailPlace = DetailPlace()
        
        // Extract the additional_data which contains most of the fields
        if let additionalData = data["additional_data"] as? [String: Any] {
            // Set basic fields
            // CRITICAL: Never create a new UUID - always use the backend's ID
            // The fallback to UUID() here is WRONG and will orphan places
            detailPlace.id = UUID(uuidString: additionalData["id"] as? String ?? "") ?? UUID()
            detailPlace.name = additionalData["name"] as? String ?? ""
            detailPlace.address = additionalData["address"] as? String
            detailPlace.city = additionalData["city"] as? String
            detailPlace.mapboxId = additionalData["mapboxId"] as? String
            
            // Set categories
            detailPlace.categories = additionalData["categories"] as? [String]
            
            // Set OpenHours
            detailPlace.openHours = additionalData["OpenHours"] as? [String]
            
            // Set coordinate
            if let coordinate = additionalData["coordinate"] as? [String: Any],
               let latitude = coordinate["latitude"] as? Double,
               let longitude = coordinate["longitude"] as? Double {
                detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
            }
        }
        
        return detailPlace
    }
        /// Test location-aware search functionality
    func testLocationAwareSearch(
        query: String = "comal",
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/test-location") else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]

        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    completion(.success(json))
                } else {
                    completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    /// Fetch place details from Mesa backend
    func fetchPlaceDetails(
        placeId: String,
        source: String,
        completion: @escaping (Result<DetailPlace, Error>) -> Void
    ) {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/place-details") else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Add query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "provider", value: source)
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "MesaBackend", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "MesaBackend", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                // First parse the data into a dictionary
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Extract the "place" object
                guard let placeDict = json?["place"] as? [String: Any] else {
                    throw NSError(domain: "MesaBackend", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
                }
                
                // Create a DetailPlace object manually
                var detailPlace = DetailPlace()
                
                // CRITICAL: Always use the backend's ID - never create a new one!
                // Creating a new ID would orphan the place in the backend
                guard let idString = placeDict["id"] as? String,
                      let placeId = UUID(uuidString: idString) else {
                    throw NSError(domain: "MesaBackend", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid place ID from backend"])
                }
                detailPlace.id = placeId
                detailPlace.name = placeDict["name"] as? String ?? ""
                detailPlace.address = placeDict["address"] as? String
                detailPlace.city = placeDict["city"] as? String
                detailPlace.description = placeDict["description"] as? String
                detailPlace.mapboxId = placeDict["mapboxId"] as? String
                detailPlace.categories = placeDict["categories"] as? [String]
                detailPlace.openHours = placeDict["openHours"] as? [String]
                detailPlace.phone = placeDict["phone"] as? String
                detailPlace.priceLevel = placeDict["priceLevel"] as? String
                detailPlace.rating = placeDict["rating"] as? Double
                detailPlace.userRatingsTotal = placeDict["ratingCount"] as? Int
                detailPlace.reservable = placeDict["reservable"] as? Bool
                detailPlace.servesBreakfast = placeDict["servesBreakfast"] as? Bool
                detailPlace.serversLunch = placeDict["servesLunch"] as? Bool
                detailPlace.serversDinner = placeDict["servesDinner"] as? Bool
                detailPlace.Instagram = placeDict["instagram"] as? String
                detailPlace.X = placeDict["twitter"] as? String
                
                // Manually extract coordinates and create GeoPoint
                if let locationDict = placeDict["location"] as? [String: Any],
                   let latitude = locationDict["latitude"] as? Double,
                   let longitude = locationDict["longitude"] as? Double {
                    detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
                }
                
                completion(.success(detailPlace))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }

    /// Fetch review photos from Firestore for a place
    func getReviewPhotos(for placeId: String, completion: @escaping ([String]) -> Void) {
        let db = Firestore.firestore()
        let reviewsRef = db.collection("places").document(placeId).collection("reviews")

        // Get up to 10 reviews to ensure we find 5 photos
        reviewsRef.limit(to: 10).getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                print("❌ [MesaBackendService] Error fetching reviews: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            var photoUrls: [String] = []

            // Loop through each review document
            for document in documents {
                let data = document.data()

                // Extract media array from review
                if let mediaArray = data["media"] as? [[String: Any]] {
                    for mediaItem in mediaArray {
                        // Check if it's an image with a URL
                        if let type = mediaItem["type"] as? String,
                           type == "image",
                           let imageUrl = mediaItem["imageUrl"] as? String {

                            photoUrls.append(imageUrl)

                            // Stop once we have 5 photos
                            if photoUrls.count >= 5 {
                                break
                            }
                        }
                    }
                }

                // Stop if we already have 5 photos
                if photoUrls.count >= 5 {
                    break
                }
            }

            print("📸 [MesaBackendService] Found \(photoUrls.count) review photos for place \(placeId)")
            completion(photoUrls)
        }
    }
}
