//
//  PlaceInsightsService.swift
//  loc
//
//  Rich place page data: TikTok mentions ("People order"), the short take,
//  TikTok photos (backend /places/<id>/insights) and friends' activity
//  (Supabase RPC get_place_friend_activity, scoped to the signed-in user).
//

import Foundation
import Supabase

struct PlaceMention: Codable, Identifiable, Hashable {
    let videoId: String
    let source: String?
    let sourceUrl: String?
    let thumbnailUrl: String?
    let author: String?
    let dishes: [String]?
    let tip: String?
    let vibe: String?
    let timestampSeconds: Int?

    var id: String { videoId }

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case source
        case sourceUrl = "source_url"
        case thumbnailUrl = "thumbnail_url"
        case author, dishes, tip, vibe
        case timestampSeconds = "timestamp_seconds"
    }
}

struct PlaceDishCount: Codable, Hashable {
    let name: String
    let count: Int
}

struct PlaceInsightPhoto: Codable, Hashable {
    let url: String
    let source: String?
    let sourceUrl: String?

    enum CodingKeys: String, CodingKey {
        case url, source
        case sourceUrl = "source_url"
    }
}

struct PlaceInsights: Codable {
    let placeId: String?
    let take: String?
    let topDishes: [PlaceDishCount]?
    let mentions: [PlaceMention]?
    let photos: [PlaceInsightPhoto]?

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case take
        case topDishes = "top_dishes"
        case mentions, photos
    }
}

struct FriendPlaceActivity: Codable, Identifiable, Hashable {
    let userId: String
    let fullName: String?
    let profilePhotoUrl: String?
    let saved: Bool?
    let listNames: [String]?
    let reviewText: String?
    let rating: Double?
    let favoriteDishes: [String]?
    let reviewImages: [String]?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case fullName = "full_name"
        case profilePhotoUrl = "profile_photo_url"
        case saved
        case listNames = "list_names"
        case reviewText = "review_text"
        case rating
        case favoriteDishes = "favorite_dishes"
        case reviewImages = "review_images"
    }
}

final class PlaceInsightsService {
    static let shared = PlaceInsightsService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    func fetchInsights(placeId: String) async throws -> PlaceInsights {
        guard let encoded = placeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(MesaBackendConfig.baseURL)/places/\(encoded)/insights") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PlaceInsights.self, from: data)
    }

    func fetchFriendActivity(placeId: String) async throws -> [FriendPlaceActivity] {
        let params: [String: String] = ["p_place_id": placeId]
        let rows: [FriendPlaceActivity] = try await SupabaseManager.shared.client
            .rpc("get_place_friend_activity", params: params)
            .execute()
            .value
        return rows
    }
}
