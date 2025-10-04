//
//  TikTokService.swift
//  loc
//
//  Created by Mesa on 7/2/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

// MARK: - TikTok Data Models
// NOTE: Most TikTok-specific data models are no longer needed since the backend 
// now returns DetailPlace format directly. Only keeping TikTokAuthor and TikTokVideo
// since they're still used in the DetailPlace model.

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

// MARK: - TikTok Service
class TikTokService: ObservableObject {
    private let baseURL = "https://mesa-backend-staging.up.railway.app"
    private let placeService = PlaceService.shared
    
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    func processTikTokURL(_ url: String) async -> Result<[DetailPlace], Error> {
        guard let requestURL = URL(string: "\(baseURL)/process-url") else {
            print("❌ [TikTokService] Invalid base URL: \(baseURL)/process-url")
            return .failure(TikTokError.invalidURL)
        }
        
        print("🌐 [TikTokService] Making request to: \(requestURL)")
        print("📝 [TikTokService] Request body: {\"url\": \"\(url)\"}")
        
        isProcessing = true
        defer { isProcessing = false }
        
        let request = await createRequest(url: requestURL, tikTokURL: url)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("📡 [TikTokService] Received response")
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 [TikTokService] Status code: \(httpResponse.statusCode)")
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 [TikTokService] Response data: \(responseString)")
            } else {
                print("❌ [TikTokService] Could not decode response data as string")
            }
            
            if let error = validateResponse(response) {
                print("❌ [TikTokService] Response validation failed: \(error)")
                return .failure(error)
            }
            
            // Parse the response - could be single place or array of places
            do {
                // First try to parse as an array of DetailPlace objects
                let detailPlaces = try JSONDecoder().decode([DetailPlace].self, from: data)
                print("✅ [TikTokService] Successfully decoded array of DetailPlaces: \(detailPlaces.count) places")
                return .success(detailPlaces)
            } catch {
                print("❌ [TikTokService] Failed to decode as array, trying single DetailPlace...")
                
                // Try to parse as a single DetailPlace
                do {
                    let detailPlace = try JSONDecoder().decode(DetailPlace.self, from: data)
                    print("✅ [TikTokService] Successfully decoded single DetailPlace: \(detailPlace.name)")
                    return .success([detailPlace]) // Wrap in array
                } catch {
                    print("❌ [TikTokService] Failed to decode as single DetailPlace, trying wrapped format...")
                    
                    // If that fails, try to parse as wrapped format like other backend responses
                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        
                        // Check if this is a response indicating no location was found
                        if let processingStatus = json?["processing_status"] as? [String: Any],
                           let locationFound = processingStatus["location_found"] as? Bool,
                           !locationFound {
                            print("❌ [TikTokService] No location found in TikTok video")
                            return .success([]) // Return empty array to indicate no places found
                        }
                        
                        // First check if it's the TikTok response format with location_info array (all detected places)
                        if let locationInfoArray = json?["location_info"] as? [[String: Any]], locationInfoArray.count > 0 {
                            print("🔍 [TikTokService] Found TikTok location_info array with \(locationInfoArray.count) places")
                            var detailPlaces: [DetailPlace] = []
                            
                            for locationDict in locationInfoArray {
                                let detailPlace = try parseLocationInfoToDetailPlace(locationDict, tikTokData: json?["data"] as? [String: Any])
                                detailPlaces.append(detailPlace)
                            }
                            
                            print("✅ [TikTokService] Successfully parsed \(detailPlaces.count) DetailPlaces from location_info array")
                            return .success(detailPlaces)
                        }
                        
                        // Check if it's the TikTok response format with saved_places array (multiple places)
                        if let savedPlacesArray = json?["saved_places"] as? [[String: Any]] {
                            print("🔍 [TikTokService] Found TikTok saved_places array with \(savedPlacesArray.count) places")
                            var detailPlaces: [DetailPlace] = []
                            
                            for placeDict in savedPlacesArray {
                                var detailPlace = try parseDetailPlaceFromDictionary(placeDict)
                                
                                // Also extract TikTok video data from the response
                                if let tikTokData = json?["data"] as? [String: Any] {
                                    if let tikTokVideo = createTikTokVideoFromResponseData(tikTokData) {
                                        detailPlace.tikTokVideos = [tikTokVideo]
                                    }
                                }
                                
                                detailPlaces.append(detailPlace)
                            }
                            
                            print("✅ [TikTokService] Successfully parsed \(detailPlaces.count) DetailPlaces from saved_places array")
                            return .success(detailPlaces)
                        }
                        
                        // Check if it's the TikTok response format with saved_place (single place)
                        if let savedPlaceDict = json?["saved_place"] as? [String: Any] {
                            print("🔍 [TikTokService] Found TikTok saved_place object, parsing...")
                            var detailPlace = try parseDetailPlaceFromDictionary(savedPlaceDict)
                            
                            // Also extract TikTok video data from the response
                            if let tikTokData = json?["data"] as? [String: Any] {
                                print("🔍 [TikTokService] Found TikTok video data, adding to place...")
                                if let tikTokVideo = createTikTokVideoFromResponseData(tikTokData) {
                                    detailPlace.tikTokVideos = [tikTokVideo]
                                    print("✅ [TikTokService] Added TikTok video to place")
                                }
                            }
                            
                            print("✅ [TikTokService] Successfully parsed TikTok DetailPlace: \(detailPlace.name)")
                            return .success([detailPlace]) // Wrap in array
                        }
                        
                        // Check if it's wrapped in a "place" object
                        if let placeDict = json?["place"] as? [String: Any] {
                            print("🔍 [TikTokService] Found wrapped place object, parsing manually...")
                            let detailPlace = try parseDetailPlaceFromDictionary(placeDict)
                            print("✅ [TikTokService] Successfully parsed wrapped DetailPlace: \(detailPlace.name)")
                            return .success([detailPlace]) // Wrap in array
                        }
                        
                        // If no wrapper, try direct parsing from the dictionary
                        if let json = json {
                            let detailPlace = try parseDetailPlaceFromDictionary(json)
                            print("✅ [TikTokService] Successfully parsed DetailPlace from dictionary: \(detailPlace.name)")
                            return .success([detailPlace]) // Wrap in array
                        }
                        
                        throw NSError(domain: "TikTokService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to parse response as DetailPlace"])
                    } catch {
                        print("❌ [TikTokService] Failed to parse response: \(error)")
                        return .failure(error)
                    }
                }
            }
            
        } catch {
            print("❌ [TikTokService] Network error: \(error)")
            return .failure(error)
        }
    }
    
    func refreshTikTokThumbnail(for url: String, userId: String?) async -> Result<String, Error> {
        print("🌐 [TikTokService] refreshTikTokThumbnail called")
        print("🌐 [TikTokService] Input URL: \(url)")
        print("🌐 [TikTokService] User ID: \(userId ?? "nil")")
        
        guard let requestURL = URL(string: "\(baseURL)/refresh-thumbnail") else {
            print("❌ [TikTokService] Failed to create request URL: \(baseURL)/refresh-thumbnail")
            return .failure(TikTokError.invalidURL)
        }
        
        print("🌐 [TikTokService] Request URL: \(requestURL)")
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: String] = ["url": url]
        if let userId = userId {
            body["user_id"] = userId
        }
        
        print("🌐 [TikTokService] Request body: \(body)")
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            print("❌ [TikTokService] Failed to serialize request body")
            return .failure(TikTokError.invalidURL)
        }
        
        request.httpBody = httpBody
        
        print("🌐 [TikTokService] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        print("🌐 [TikTokService] Request body string: \(String(data: httpBody, encoding: .utf8) ?? "nil")")
        
        do {
            print("🌐 [TikTokService] Making HTTP request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("🌐 [TikTokService] Received response")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 [TikTokService] HTTP Status Code: \(httpResponse.statusCode)")
                print("🌐 [TikTokService] Response headers: \(httpResponse.allHeaderFields)")
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("🌐 [TikTokService] Raw response data: \(responseString)")
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ [TikTokService] Failed to parse JSON response")
                return .failure(TikTokError.invalidResponse)
            }
            
            print("🌐 [TikTokService] Parsed JSON: \(json)")
            
            if let thumbnailURL = json["thumbnailURL"] as? String {
                print("✅ [TikTokService] SUCCESS: Extracted thumbnail URL: \(thumbnailURL)")
                
                // Test if the URL is valid
                if let testURL = URL(string: thumbnailURL) {
                    print("✅ [TikTokService] URL is valid: \(testURL)")
                } else {
                    print("⚠️ [TikTokService] Warning: thumbnailURL is not a valid URL")
                }
                
                return .success(thumbnailURL)
            } else if let errorMsg = json["error"] as? String {
                print("❌ [TikTokService] Backend error: \(errorMsg)")
                return .failure(NSError(domain: "TikTokService", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            } else {
                print("❌ [TikTokService] No thumbnailURL or error in response")
                return .failure(TikTokError.invalidResponse)
            }
        } catch {
            print("❌ [TikTokService] HTTP request failed: \(error)")
            if let nsError = error as NSError? {
                print("❌ [TikTokService] Error domain: \(nsError.domain)")
                print("❌ [TikTokService] Error code: \(nsError.code)")
                print("❌ [TikTokService] Error userInfo: \(nsError.userInfo)")
            }
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
    
    // MARK: - Helper Methods
    
    private func parseLocationInfoToDetailPlace(_ locationDict: [String: Any], tikTokData: [String: Any]?) throws -> DetailPlace {
        // Extract basic info from location_info format
        let name = locationDict["business_name"] as? String ?? locationDict["location_name"] as? String ?? ""
        let placeIdString = locationDict["place_id"] as? String ?? UUID().uuidString
        let placeId = UUID(uuidString: placeIdString) ?? UUID()
        
        // Extract address
        let address = locationDict["formatted_address"] as? String
        
        // Create DetailPlace with basic initializer
        var detailPlace = DetailPlace(
            id: placeId,
            name: name,
            address: address,
            city: nil
        )
        
        // Set coordinate separately
        if let coordinatesArray = locationDict["coordinates"] as? [Double], coordinatesArray.count >= 2 {
            detailPlace.coordinate = GeoPoint(latitude: coordinatesArray[0], longitude: coordinatesArray[1])
        }
        
        // Add TikTok video data if available
        if let tikTokData = tikTokData, let tikTokVideo = createTikTokVideoFromResponseData(tikTokData) {
            detailPlace.tikTokVideos = [tikTokVideo]
        }
        
        return detailPlace
    }
    
    /// Parse DetailPlace from dictionary (for handling backend responses that might be wrapped)
    private func parseDetailPlaceFromDictionary(_ dict: [String: Any]) throws -> DetailPlace {
        var detailPlace = DetailPlace()
        
        // Basic fields
        detailPlace.id = UUID(uuidString: dict["id"] as? String ?? "") ?? UUID()
        detailPlace.name = dict["name"] as? String ?? ""
        detailPlace.address = dict["address"] as? String
        detailPlace.city = dict["city"] as? String
        detailPlace.description = dict["description"] as? String
        detailPlace.mapboxId = dict["mapboxId"] as? String
        detailPlace.googlePlaceId = dict["googlePlaceId"] as? String
        detailPlace.source = dict["source"] as? String
        
        // Categories
        detailPlace.categories = dict["categories"] as? [String]
        
        // Hours and contact
        detailPlace.openHours = dict["openHours"] as? [String]
        detailPlace.phone = dict["phone"] as? String
        
        // Rating and price
        detailPlace.rating = dict["rating"] as? Double
        detailPlace.priceLevel = dict["priceLevel"] as? String
        
        // Service flags
        detailPlace.reservable = dict["reservable"] as? Bool
        detailPlace.servesBreakfast = dict["servesBreakfast"] as? Bool
        detailPlace.serversLunch = dict["servesLunch"] as? Bool
        detailPlace.serversDinner = dict["serversDinner"] as? Bool
        
        // Social media
        detailPlace.Instagram = dict["instagram"] as? String
        detailPlace.X = dict["twitter"] as? String
        
        // Handle coordinates
        if let coordinateDict = dict["coordinate"] as? [String: Any],
           let latitude = coordinateDict["latitude"] as? Double,
           let longitude = coordinateDict["longitude"] as? Double {
            detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
        } else if let locationDict = dict["location"] as? [String: Any],
                  let latitude = locationDict["latitude"] as? Double,
                  let longitude = locationDict["longitude"] as? Double {
            detailPlace.coordinate = GeoPoint(latitude: latitude, longitude: longitude)
        }
        
        // Handle TikTok videos if present
        if let tikTokVideosArray = dict["tikTokVideos"] as? [[String: Any]] {
            detailPlace.tikTokVideos = tikTokVideosArray.compactMap { videoDict in
                guard let videoID = videoDict["videoID"] as? String,
                      let url = videoDict["url"] as? String else {
                    return nil
                }
                
                let author = TikTokAuthor(
                    displayName: videoDict["author_display_name"] as? String ?? "",
                    url: videoDict["author_url"] as? String ?? "",
                    username: videoDict["author_username"] as? String ?? ""
                )
                
                return TikTokVideo(
                    videoID: videoID,
                    url: url,
                    title: videoDict["title"] as? String,
                    caption: videoDict["caption"] as? String,
                    embedHTML: videoDict["embedHTML"] as? String ?? "",
                    thumbnailURL: videoDict["thumbnailURL"] as? String ?? "",
                    author: author,
                    hashtags: videoDict["hashtags"] as? [String] ?? [],
                    createdAt: videoDict["createdAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
                )
            }
        }
        
        // Handle creation date
        if let createdAtString = dict["createdAt"] as? String {
            detailPlace.createdAt = createdAtString
        } else {
            // Default to current date string if not provided
            let formatter = ISO8601DateFormatter()
            detailPlace.createdAt = formatter.string(from: Date())
        }
        
        return detailPlace
    }
    
    /// Create TikTok video from response data
    private func createTikTokVideoFromResponseData(_ data: [String: Any]) -> TikTokVideo? {
        guard let url = data["url"] as? String else {
            print("❌ [TikTokService] Missing URL in TikTok data")
            return nil
        }
        
        // Extract video ID from URL or photo ID
        let videoID: String
        if let photoId = data["photo_id"] as? String {
            videoID = photoId
        } else if let extractedId = extractVideoIdFromURL(url) {
            videoID = extractedId
        } else {
            videoID = UUID().uuidString // Fallback
        }
        
        // Create author
        let author = TikTokAuthor(
            displayName: data["author_name"] as? String ?? "",
            url: data["author_url"] as? String ?? "",
            username: extractUsernameFromURL(data["author_url"] as? String)
        )
        
        // Create video
        return TikTokVideo(
            videoID: videoID,
            url: url,
            title: data["title"] as? String,
            caption: data["title"] as? String, // Use title as caption if no separate caption
            embedHTML: "", // Not provided in this format
            thumbnailURL: data["thumbnail_url"] as? String ?? "",
            author: author,
            hashtags: data["hashtags"] as? [String] ?? [],
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    /// Extract video ID from TikTok URL
    private func extractVideoIdFromURL(_ url: String) -> String? {
        // Try to extract from various TikTok URL formats
        let patterns = [
            "/photo/([0-9]+)",
            "/video/([0-9]+)",
            "@[^/]+/video/([0-9]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(location: 0, length: url.count)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        
        return nil
    }
    
    /// Extract username from TikTok author URL
    private func extractUsernameFromURL(_ url: String?) -> String {
        guard let url = url else { return "" }
        
        // Extract @username from URL like https://www.tiktok.com/@username
        if let regex = try? NSRegularExpression(pattern: "@([^/?]+)"),
           let match = regex.firstMatch(in: url, range: NSRange(location: 0, length: url.count)),
           let range = Range(match.range(at: 1), in: url) {
            return String(url[range])
        }
        
        return ""
    }
    
    // NOTE: Frontend does NOT save to Firestore - backend handles all writes
    // Places are created/saved via backend API calls only
    
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
    case invalidResponse
    
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
        case .invalidResponse:
            return "Invalid response received from backend"
        }
    }
}