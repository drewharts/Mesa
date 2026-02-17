import Foundation
import CoreLocation

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

/// DTO matching the exact JSON shape returned by the Mesa backend for place data.
/// Used by both /search/place-details and /search/ai-suggestions endpoints.
/// JSONDecoder handles type coercion (Int/Double) correctly, unlike manual `as?` casts.
struct BackendPlaceDTO: Codable {
    let id: String
    let name: String
    let address: String?
    let city: String?
    let description: String?
    let mapboxId: String?
    let categories: [String]?
    let openHours: [String]?
    let phone: String?
    let priceLevel: String?
    let rating: Double?
    let ratingCount: Int?
    let reservable: Bool?
    let servesBreakfast: Bool?
    let servesLunch: Bool?
    let servesDinner: Bool?
    let instagram: String?
    let twitter: String?
    let menuUrl: String?
    let website: String?
    let isCustom: Bool?
    let googlePlacesId: String?
    let thumbnailUrl: String?
    let coordinate: BackendCoordinateDTO?
    let location: BackendCoordinateDTO?
    let aiSuggestionReason: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, address, city, description, mapboxId, categories, openHours
        case phone, priceLevel, rating, ratingCount, reservable
        case servesBreakfast, servesLunch, servesDinner
        case instagram, twitter, menuUrl, website
        case isCustom, googlePlacesId, thumbnailUrl
        case coordinate, location, aiSuggestionReason
    }

    /// Helper DTO for decoding openHours when the backend returns objects instead of strings.
    private struct OpenHoursEntry: Decodable {
        let day: String
        let hours: String
    }

    /// Decodes all fields, delegating openHours to a flexible decoder.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        mapboxId = try container.decodeIfPresent(String.self, forKey: .mapboxId)
        categories = try container.decodeIfPresent([String].self, forKey: .categories)
        openHours = Self.decodeOpenHours(from: container)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        priceLevel = try container.decodeIfPresent(String.self, forKey: .priceLevel)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        ratingCount = try container.decodeIfPresent(Int.self, forKey: .ratingCount)
        reservable = try container.decodeIfPresent(Bool.self, forKey: .reservable)
        servesBreakfast = try container.decodeIfPresent(Bool.self, forKey: .servesBreakfast)
        servesLunch = try container.decodeIfPresent(Bool.self, forKey: .servesLunch)
        servesDinner = try container.decodeIfPresent(Bool.self, forKey: .servesDinner)
        instagram = try container.decodeIfPresent(String.self, forKey: .instagram)
        twitter = try container.decodeIfPresent(String.self, forKey: .twitter)
        menuUrl = try container.decodeIfPresent(String.self, forKey: .menuUrl)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom)
        googlePlacesId = try container.decodeIfPresent(String.self, forKey: .googlePlacesId)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        coordinate = try container.decodeIfPresent(BackendCoordinateDTO.self, forKey: .coordinate)
        location = try container.decodeIfPresent(BackendCoordinateDTO.self, forKey: .location)
        aiSuggestionReason = try container.decodeIfPresent(String.self, forKey: .aiSuggestionReason)
    }

    /// Decodes openHours flexibly: tries [String] first, falls back to [{day, hours}] objects.
    private static func decodeOpenHours(from container: KeyedDecodingContainer<CodingKeys>) -> [String]? {
        if let strings = try? container.decodeIfPresent([String].self, forKey: .openHours) {
            return strings
        } else if let entries = try? container.decodeIfPresent([OpenHoursEntry].self, forKey: .openHours) {
            return entries.map { "\($0.day): \($0.hours)" }
        }
        return nil
    }

    /// Converts this DTO into a DetailPlace domain model via PlaceDataAssembler.
    func toDetailPlace() -> DetailPlace? {
        PlaceDataAssembler.assemble(from: self)
    }
}

/// DTO for coordinate objects in backend responses.
struct BackendCoordinateDTO: Codable {
    let latitude: Double?
    let longitude: Double?
}

/// Response wrapper for the /search/place-details endpoint.
struct BackendPlaceDetailsResponse: Codable {
    let place: BackendPlaceDTO
}

/// Response wrapper for the /search/ai-suggestions endpoint.
struct BackendAISuggestionsResponse: Codable {
    let suggestions: [BackendPlaceDTO]
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

// MARK: - Mesa Backend Errors

/// Errors that can occur when calling the Mesa backend.
enum MesaBackendError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidJSON
    case invalidPlaceId
    case serverError(statusCode: Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidJSON:
            return "Invalid JSON structure"
        case .invalidPlaceId:
            return "Invalid place ID from backend"
        case .serverError(let statusCode):
            return "Server returned status code \(statusCode)"
        case .noData:
            return "No data received"
        }
    }
}

// MARK: - Mesa Backend Service

/// Service class for the Mesa backend API
class MesaBackendService {
    static let shared = MesaBackendService()

    private let baseURL = MesaBackendConfig.baseURL
    private let session: URLSession

    init() {
        // Create custom URLSession configuration to avoid connection pooling issues
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Async/Await API

    /// Fetches place details using async/await - preferred method.
    /// Backend checks Supabase cache first, then falls back to external APIs.
    func fetchPlaceDetails(placeId: String, source: String = "google") async throws -> DetailPlace {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/place-details") else {
            throw MesaBackendError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "provider", value: source)
        ]

        guard let url = urlComponents.url else {
            throw MesaBackendError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MesaBackendError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MesaBackendError.serverError(statusCode: httpResponse.statusCode)
        }

        return try parsePlaceDetailsResponse(data: data)
    }

    /// Fetches AI-powered place suggestions using async/await.
    func fetchAISuggestions(query: String, latitude: Double, longitude: Double, limit: Int = 5) async throws -> [DetailPlace] {
        guard !query.isEmpty else { return [] }

        guard let url = URL(string: "\(baseURL)/search/ai-suggestions") else {
            throw MesaBackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": query,
            "latitude": latitude,
            "longitude": longitude,
            "limit": limit
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MesaBackendError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MesaBackendError.serverError(statusCode: httpResponse.statusCode)
        }

        return try parseAISuggestionsResponse(data: data)
    }

    /// Fetches place suggestions using async/await.
    func fetchSuggestions(query: String, limit: Int = 5, provider: String = "google", latitude: Double? = nil, longitude: Double? = nil) async throws -> [MesaPlaceSuggestion] {
        guard !query.isEmpty else { return [] }

        guard var urlComponents = URLComponents(string: "\(baseURL)/search/suggestions") else {
            throw MesaBackendError.invalidURL
        }

        var queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "provider", value: provider)
        ]

        if let latitude = latitude {
            queryItems.append(URLQueryItem(name: "latitude", value: String(latitude)))
        }
        if let longitude = longitude {
            queryItems.append(URLQueryItem(name: "longitude", value: String(longitude)))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw MesaBackendError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MesaBackendError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MesaBackendError.serverError(statusCode: httpResponse.statusCode)
        }

        let suggestionsResponse = try JSONDecoder().decode(MesaSuggestionsResponse.self, from: data)

        return suggestionsResponse.suggestions.map { suggestion in
            MesaPlaceSuggestion(
                id: suggestion.id,
                name: suggestion.name,
                address: suggestion.address,
                coordinate: CLLocationCoordinate2D(
                    latitude: suggestion.location.latitude,
                    longitude: suggestion.location.longitude
                ),
                source: suggestion.source
            )
        }
    }

    // MARK: - Response Parsing

    /// Parses place details response from backend, logging raw response on failure.
    private func parsePlaceDetailsResponse(data: Data) throws -> DetailPlace {
        do {
            let response = try JSONDecoder().decode(BackendPlaceDetailsResponse.self, from: data)
            guard let place = response.place.toDetailPlace() else {
                throw MesaBackendError.invalidPlaceId
            }
            return place
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
            print("❌ [MesaBackendService] Failed to decode place details response: \(error)")
            print("❌ [MesaBackendService] Raw response: \(rawResponse)")
            throw error
        }
    }
    
    // MARK: - Legacy Callback API (for backwards compatibility)

    /// Fetch place suggestions from Mesa backend (callback version).
    func fetchSuggestions(
        query: String,
        limit: Int = 5,
        provider: String = "google",
        latitude: Double? = nil,
        longitude: Double? = nil,
        completion: @escaping (Result<[MesaPlaceSuggestion], Error>) -> Void
    ) {
        Task {
            do {
                let suggestions = try await fetchSuggestions(
                    query: query,
                    limit: limit,
                    provider: provider,
                    latitude: latitude,
                    longitude: longitude
                )
                completion(.success(suggestions))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Fetch place details from Mesa backend (callback version).
    func fetchPlaceDetails(
        placeId: String,
        source: String,
        completion: @escaping (Result<DetailPlace, Error>) -> Void
    ) {
        Task {
            do {
                let place = try await fetchPlaceDetails(placeId: placeId, source: source)
                completion(.success(place))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Fetch AI-powered place suggestions from Mesa backend (callback version).
    func fetchAISuggestions(
        query: String,
        latitude: Double,
        longitude: Double,
        limit: Int = 5,
        completion: @escaping (Result<[DetailPlace], Error>) -> Void
    ) {
        Task {
            do {
                let places = try await fetchAISuggestions(
                    query: query,
                    latitude: latitude,
                    longitude: longitude,
                    limit: limit
                )
                completion(.success(places))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Image Refresh API

    /// Response model for image refresh endpoint.
    struct ImageRefreshResponse: Codable {
        let status: String
        let reviews_queued: Int
        let message: String?
    }

    /// Requests the backend to refresh stale external review images for a place.
    /// Called when iOS detects 403 errors on Google CDN image URLs.
    func requestImageRefresh(placeId: String, failedURLs: [String] = []) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/search/refresh-review-images") else {
            throw MesaBackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "place_id": placeId,
            "failed_urls": failedURLs
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MesaBackendError.invalidResponse
        }

        // 429 = rate limited, treat as "no refresh needed right now"
        if httpResponse.statusCode == 429 {
            print("📸 [MesaBackendService] Image refresh rate limited for place \(placeId)")
            return false
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MesaBackendError.serverError(statusCode: httpResponse.statusCode)
        }

        let refreshResponse = try JSONDecoder().decode(ImageRefreshResponse.self, from: data)
        let refreshInitiated = refreshResponse.status == "processing"

        print("📸 [MesaBackendService] Image refresh response: \(refreshResponse.status), queued: \(refreshResponse.reviews_queued)")

        return refreshInitiated
    }

    // MARK: - Private Response Parsing

    /// Decodes AI suggestions response using type-safe JSONDecoder.
    private func parseAISuggestionsResponse(data: Data) throws -> [DetailPlace] {
        let response = try JSONDecoder().decode(BackendAISuggestionsResponse.self, from: data)
        return response.suggestions.compactMap { $0.toDetailPlace() }
    }
}
