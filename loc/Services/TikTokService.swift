//
//  TikTokService.swift
//  loc
//
//  Created by Mesa on 7/2/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - TikTok Data Models
struct TikTokProcessorResponse: Codable {
    let data: TikTokData
    let locationInfo: TikTokLocationInfo
    let processorType: String
    let placeSaved: Bool?
    let placeId: String?
    let externalPlaceId: String?
    let placeAlreadyExisted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case data
        case locationInfo = "location_info"
        case processorType = "processor_type"
        case placeSaved = "place_saved"
        case placeId = "place_id"
        case externalPlaceId = "external_place_id"
        case placeAlreadyExisted = "place_already_existed"
    }
}

struct TikTokData: Codable {
    let author: TikTokAuthor
    let caption: String
    let embedHTML: String
    let hashtags: [String]
    let location: String?
    let thumbnailURL: String
    let title: String
    let url: String
    let videoID: String
    
    enum CodingKeys: String, CodingKey {
        case author
        case caption
        case embedHTML = "embed_html"
        case hashtags
        case location
        case thumbnailURL = "thumbnail_url"
        case title
        case url
        case videoID = "video_id"
    }
}

struct TikTokAuthor: Codable, Equatable {
    let displayName: String
    let url: String
    let username: String
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case url
        case username
    }
}

struct TikTokLocationInfo: Codable {
    let addressComponents: TikTokAddressComponents
    let coordinates: [Double]
    let formattedAddress: String
    let locationName: String
    let placeID: String
    let rawText: String
    
    enum CodingKeys: String, CodingKey {
        case addressComponents = "address_components"
        case coordinates
        case formattedAddress = "formatted_address"
        case locationName = "location_name"
        case placeID = "place_id"
        case rawText = "raw_text"
    }
}

struct TikTokAddressComponents: Codable {
    let city: String
    let country: String
    let postalCode: String
    let state: String
    
    enum CodingKeys: String, CodingKey {
        case city
        case country
        case postalCode = "postal_code"
        case state
    }
}

// MARK: - TikTok Video Model for Firebase
struct TikTokVideo: Codable, Identifiable, Equatable {
    var id = UUID()
    let videoID: String
    let url: String
    let title: String?
    let caption: String?
    let embedHTML: String
    let thumbnailURL: String
    let author: TikTokAuthor
    let hashtags: [String]
    let createdAt: String  // Changed from Date to String to match backend
    
    enum CodingKeys: String, CodingKey {
        case id
        case videoID = "video_id"
        case url
        case title
        case caption
        case embedHTML = "embed_html"
        case thumbnailURL = "thumbnail_url"
        case author
        case hashtags
        case createdAt = "created_at"
    }
    
    // Manual initializer
    init(id: UUID = UUID(), videoID: String, url: String, title: String?, caption: String?, embedHTML: String, thumbnailURL: String, author: TikTokAuthor, hashtags: [String], createdAt: String) {
        self.id = id
        self.videoID = videoID
        self.url = url
        self.title = title
        self.caption = caption
        self.embedHTML = embedHTML
        self.thumbnailURL = thumbnailURL
        self.author = author
        self.hashtags = hashtags
        self.createdAt = createdAt
    }
    
    // Custom decoder to handle the backend format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Generate a UUID for the id if not present
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        
        self.videoID = try container.decode(String.self, forKey: .videoID)
        self.url = try container.decode(String.self, forKey: .url)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.caption = try container.decodeIfPresent(String.self, forKey: .caption) ?? ""
        self.embedHTML = try container.decodeIfPresent(String.self, forKey: .embedHTML) ?? ""
        self.thumbnailURL = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) ?? ""
        self.author = try container.decode(TikTokAuthor.self, forKey: .author)
        self.hashtags = try container.decodeIfPresent([String].self, forKey: .hashtags) ?? []
        
        // Handle date as string
        if let dateString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            self.createdAt = dateString
        } else {
            // Default to current date string if not provided
            let formatter = ISO8601DateFormatter()
            self.createdAt = formatter.string(from: Date())
        }
    }
}

// MARK: - TikTok Service
class TikTokService: ObservableObject {
    private let baseURL = "https://mesa-backend-production.up.railway.app"
    private let placeService = PlaceService.shared
    
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    func processTikTokURL(_ url: String) async -> Result<TikTokProcessorResponse, Error> {
        guard let requestURL = URL(string: "\(baseURL)/process-url") else {
            return .failure(TikTokError.invalidURL)
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let request = await createRequest(url: requestURL, tikTokURL: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let error = validateResponse(response) {
                return .failure(error)
            }
            
            let processorResponse = try JSONDecoder().decode(TikTokProcessorResponse.self, from: data)
            return .success(processorResponse)
            
        } catch {
            return .failure(error)
        }
    }
    
    private func createRequest(url: URL, tikTokURL: String) async -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase authentication token
        await addAuthenticationToken(to: &request)
        
        // Set request body
        let requestBody = ["url": tikTokURL]
        if let jsonData = try? JSONEncoder().encode(requestBody) {
            request.httpBody = jsonData
        }
        
        return request
    }
    
    private func addAuthenticationToken(to request: inout URLRequest) async {
        if let currentUser = Auth.auth().currentUser {
            do {
                let idToken = try await currentUser.getIDToken()
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            } catch {
                // Continue without auth token - backend supports unauthenticated requests
            }
        }
    }
    
    private func validateResponse(_ response: URLResponse?) -> TikTokError? {
        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                return .authenticationRequired
            }
            return .serverError(httpResponse.statusCode)
        }
        
        return nil
    }
    
    func createPlaceFromTikTok(_ response: TikTokProcessorResponse) -> DetailPlace {
        // Determine the place ID to use
        let placeId: UUID
        if let backendPlaceId = response.placeId, let uuid = UUID(uuidString: backendPlaceId) {
            placeId = uuid
        } else {
            placeId = UUID(uuidString: response.locationInfo.placeID) ?? UUID()
        }
        
        var place = DetailPlace()
        place.id = placeId
        place.name = response.locationInfo.locationName
        place.address = response.locationInfo.formattedAddress
        place.city = response.locationInfo.addressComponents.city
        place.coordinate = GeoPoint(
            latitude: response.locationInfo.coordinates[0],
            longitude: response.locationInfo.coordinates[1]
        )
        
        // Create TikTok video object
        let formatter = ISO8601DateFormatter()
        let tikTokVideo = TikTokVideo(
            id: UUID(),
            videoID: response.data.videoID,
            url: response.data.url,
            title: response.data.title,
            caption: response.data.caption,
            embedHTML: response.data.embedHTML,
            thumbnailURL: response.data.thumbnailURL,
            author: response.data.author,
            hashtags: response.data.hashtags,
            createdAt: formatter.string(from: Date())
        )
        
        // Add TikTok video to place
        place.tikTokVideos = [tikTokVideo]
        
        // Set categories based on hashtags
        place.categories = response.data.hashtags.filter { foodCategories.contains($0.lowercased()) }
        
        return place
    }
    
    func savePlaceToFirestore(_ place: DetailPlace) async -> Result<Void, Error> {
        return await withCheckedContinuation { continuation in
            do {
                try Firestore.firestore().collection("places").document(place.id.uuidString).setData(from: place) { error in
                    if let error = error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            } catch {
                continuation.resume(returning: .failure(error))
            }
        }
    }
    
    private let foodCategories = [
        "restaurant", "food", "foodie", "coffee", "cafe", "bar", "pizza", "sushi", 
        "burger", "chinese", "italian", "mexican", "thai", "vietnamese", "japanese",
        "korean", "indian", "mediterranean", "breakfast", "lunch", "dinner", "brunch"
    ]
}

enum TikTokError: Error, LocalizedError {
    case invalidURL
    case serverError(Int)
    case processingFailed
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .serverError(let code):
            return "Server error: \(code)"
        case .processingFailed:
            return "Failed to process TikTok video"
        case .authenticationRequired:
            return "Authentication required to save place"
        }
    }
}