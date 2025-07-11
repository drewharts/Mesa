//
//  TikTokAuthService.swift
//  loc
//
//  Created by Mesa on 7/7/25.
//

import Foundation
import FirebaseAuth
import SwiftUI
import FirebaseFirestore

struct TikTokAuthStatus: Codable {
    let connected: Bool
    let expired: Bool
    let message: String
    let connectedAt: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case connected
        case expired
        case message
        case connectedAt = "connected_at"
        case scope
    }
}

struct TikTokUserInfo: Codable {
    let openId: String
    let displayName: String
    let avatarUrl: String
    let unionId: String?
    
    enum CodingKeys: String, CodingKey {
        case openId = "open_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case unionId = "union_id"
    }
}

struct TikTokCompleteResponse: Codable {
    let success: Bool
    let message: String
    let tikTokUserInfo: TikTokUserInfo?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case tikTokUserInfo = "tiktok_user_info"
    }
}

class TikTokAuthService: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isCheckingStatus: Bool = false
    @Published var connectedAt: Date?
    @Published var tikTokUserInfo: TikTokUserInfo?
    @Published var isCompletingConnection: Bool = false
    
    private let baseURL = "https://mesa.drewharts.com"
    
    init() {
        Task {
            await checkConnectionStatus()
        }
    }
    
    // Check TikTok connection status
    @MainActor
    func checkConnectionStatus() async {
        isCheckingStatus = true
        defer { isCheckingStatus = false }
        
        guard let user = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else {
            isConnected = false
            return
        }
        
        guard let url = URL(string: "\(baseURL)/auth/tiktok/status") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                let status = try JSONDecoder().decode(TikTokAuthStatus.self, from: data)
                isConnected = status.connected
                
                if let connectedAtString = status.connectedAt {
                    let formatter = ISO8601DateFormatter()
                    connectedAt = formatter.date(from: connectedAtString)
                }
            } else {
                isConnected = false
                connectedAt = nil
                tikTokUserInfo = nil
            }
        } catch {
            print("Error checking TikTok status: \(error)")
            isConnected = false
        }
    }
    
    // Initiate TikTok OAuth flow
    func connectTikTok() {
        guard let url = URL(string: "\(baseURL)/auth/tiktok/login") else { return }
        
        // Open in Safari for OAuth flow
        UIApplication.shared.open(url)
    }
    
    // Complete TikTok connection after OAuth success
    @MainActor
    func completeTikTokConnection(connectionId: String) async -> Bool {
        print("🎵 TikTokAuth: Starting connection completion with ID: \(connectionId)")
        isCompletingConnection = true
        defer { 
            isCompletingConnection = false
            print("🎵 TikTokAuth: Connection completion finished")
        }
        
        guard let user = Auth.auth().currentUser else {
            print("❌ TikTokAuth: No Firebase user for completion")
            return false
        }
        
        guard let token = try? await user.getIDToken() else {
            print("❌ TikTokAuth: Failed to get Firebase token for completion")
            return false
        }
        
        print("✅ TikTokAuth: Got Firebase token for completion")
        
        guard let url = URL(string: "\(baseURL)/auth/tiktok/complete") else { 
            print("❌ TikTokAuth: Invalid complete URL")
            return false 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["connection_id": connectionId]
        guard let jsonData = try? JSONEncoder().encode(requestBody) else { return false }
        request.httpBody = jsonData
        
        do {
            print("🌐 TikTokAuth: Making completion request to \(url)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 TikTokAuth: Completion response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📦 TikTokAuth: Completion response: \(responseString)")
                    }
                    
                    let completeResponse = try JSONDecoder().decode(TikTokCompleteResponse.self, from: data)
                    print("✅ TikTokAuth: Decoded completion response - success: \(completeResponse.success)")
                    
                    if completeResponse.success {
                        // Update local state
                        isConnected = true
                        tikTokUserInfo = completeResponse.tikTokUserInfo
                        connectedAt = Date()
                        print("✅ TikTokAuth: Updated local state - isConnected: true")
                        
                        // Refresh full status to get latest info
                        await checkConnectionStatus()
                        
                        return true
                    }
                } else {
                    print("❌ TikTokAuth: Non-200 completion status: \(httpResponse.statusCode)")
                }
            }
            
            return false
        } catch {
            print("❌ TikTokAuth: Error completing connection: \(error)")
            return false
        }
    }
    
    // Disconnect TikTok account
    @MainActor
    func disconnectTikTok() async -> Bool {
        guard let user = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else {
            return false
        }
        
        guard let url = URL(string: "\(baseURL)/auth/tiktok/disconnect") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                isConnected = false
                connectedAt = nil
                tikTokUserInfo = nil
                return true
            }
            return false
        } catch {
            print("Error disconnecting TikTok: \(error)")
            return false
        }
    }
    
    // Process URL with TikTok authentication
    func processTikTokURLWithAuth(_ urlString: String) async -> Result<DetailPlace, Error> {
        print("🎵 [TikTokAuth] Processing URL with authentication: \(urlString)")
        
        guard let user = Auth.auth().currentUser,
              let token = try? await user.getIDToken() else {
            print("❌ [TikTokAuth] User not authenticated")
            return .failure(NSError(domain: "TikTokAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
        }
        
        guard let url = URL(string: "\(baseURL)/process-url-with-auth") else {
            print("❌ [TikTokAuth] Invalid URL: \(baseURL)/process-url-with-auth")
            return .failure(NSError(domain: "TikTokAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["url": urlString]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("🌐 [TikTokAuth] Making authenticated request to: \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 [TikTokAuth] Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    // Token expired, need to reconnect
                    print("❌ [TikTokAuth] TikTok authorization expired")
                    isConnected = false
                    return .failure(NSError(domain: "TikTokAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "TikTok authorization expired"]))
                }
                
                if httpResponse.statusCode == 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📄 [TikTokAuth] Response data: \(responseString)")
                    }
                    
                    // Try to parse as DetailPlace directly first
                    do {
                        let detailPlace = try JSONDecoder().decode(DetailPlace.self, from: data)
                        print("✅ [TikTokAuth] Successfully decoded DetailPlace: \(detailPlace.name)")
                        return .success(detailPlace)
                    } catch {
                        print("❌ [TikTokAuth] Failed to decode as DetailPlace directly, trying wrapped format...")
                        
                        // Try wrapped format
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            
                            // Check if it's the TikTok response format with saved_place
                            if let savedPlaceDict = json?["saved_place"] as? [String: Any] {
                                print("🔍 [TikTokAuth] Found TikTok saved_place object")
                                var detailPlace = try parseDetailPlaceFromDictionary(savedPlaceDict)
                                
                                // Also extract TikTok video data from the response
                                if let tikTokData = json?["data"] as? [String: Any] {
                                    print("🔍 [TikTokAuth] Found TikTok video data, adding to place...")
                                    if let tikTokVideo = createTikTokVideoFromResponseData(tikTokData) {
                                        detailPlace.tikTokVideos = [tikTokVideo]
                                        print("✅ [TikTokAuth] Added TikTok video to place")
                                    }
                                }
                                
                                print("✅ [TikTokAuth] Successfully parsed TikTok DetailPlace: \(detailPlace.name)")
                                return .success(detailPlace)
                            }
                            
                            if let placeDict = json?["place"] as? [String: Any] {
                                print("🔍 [TikTokAuth] Found wrapped place object")
                                let detailPlace = try parseDetailPlaceFromDictionary(placeDict)
                                print("✅ [TikTokAuth] Successfully parsed wrapped DetailPlace: \(detailPlace.name)")
                                return .success(detailPlace)
                            }
                            
                            if let json = json {
                                let detailPlace = try parseDetailPlaceFromDictionary(json)
                                print("✅ [TikTokAuth] Successfully parsed DetailPlace from dictionary: \(detailPlace.name)")
                                return .success(detailPlace)
                            }
                            
                            throw NSError(domain: "TikTokAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to parse response as DetailPlace"])
                        } catch {
                            print("❌ [TikTokAuth] Failed to parse response: \(error)")
                            return .failure(error)
                        }
                    }
                } else {
                    print("❌ [TikTokAuth] Server error with status code: \(httpResponse.statusCode)")
                    return .failure(NSError(domain: "TikTokAuth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error"]))
                }
            }
            
            return .failure(NSError(domain: "TikTokAuth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
        } catch {
            print("❌ [TikTokAuth] Network error: \(error)")
            return .failure(error)
        }
    }
    
    /// Parse DetailPlace from dictionary (reusing the same logic as TikTokService)
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
            print("❌ [TikTokAuth] Missing URL in TikTok data")
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
}
