//
//  PlaceInsightsViewModel.swift
//  loc
//

import Foundation

@MainActor
final class PlaceInsightsViewModel: ObservableObject {
    @Published private(set) var take: String?
    @Published private(set) var topDishes: [PlaceDishCount] = []
    @Published private(set) var mentions: [PlaceMention] = []
    @Published private(set) var friends: [FriendPlaceActivity] = []
    @Published private(set) var priorityPhotoURLs: [String] = []

    private var loadedPlaceId: String?

    var hasPeopleOrder: Bool { !topDishes.isEmpty || mentions.contains { ($0.tip ?? "").isEmpty == false || ($0.vibe ?? "").isEmpty == false } }

    func load(placeId: String) async {
        guard !placeId.isEmpty, placeId != loadedPlaceId else { return }
        loadedPlaceId = placeId
        take = nil
        topDishes = []
        mentions = []
        friends = []
        priorityPhotoURLs = []

        async let insightsResult: PlaceInsights? = try? PlaceInsightsService.shared.fetchInsights(placeId: placeId)
        async let friendsResult: [FriendPlaceActivity]? = try? PlaceInsightsService.shared.fetchFriendActivity(placeId: placeId)
        let insights = await insightsResult
        let friendRows = await friendsResult ?? []
        guard loadedPlaceId == placeId else { return }

        let trimmedTake = insights?.take?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        take = (trimmedTake.isEmpty || trimmedTake.hasPrefix("{")) ? nil : trimmedTake
        topDishes = insights?.topDishes ?? []
        mentions = insights?.mentions ?? []
        friends = friendRows

        // Photos first: TikTok thumbnails, then friends' review photos (Google photos follow in the gallery).
        var urls: [String] = []
        for photo in insights?.photos ?? [] where !urls.contains(photo.url) { urls.append(photo.url) }
        for friend in friendRows {
            for image in friend.reviewImages ?? [] where !image.isEmpty && !urls.contains(image) { urls.append(image) }
        }
        priorityPhotoURLs = urls
    }
}
