//
//  FreshFindsViewModel.swift
//  loc
//
//  Feeds the Fresh finds card stack: recently imported places (TikTok / Instagram videos
//  imported by anyone), newest first, via the existing `get_explore_external_videos` RPC.
//  Pages with limit/offset (never relies on a single >1000-row response), dedupes by place,
//  and only surfaces a card once its photo has actually loaded — places whose photos fail
//  (expired Google links, dead CDN thumbnails) are skipped.
//

import SwiftUI

struct FreshFind: Identifiable {
    let item: ExploreVideoItem
    let image: UIImage
    var id: String { item.placeId }
}

@MainActor
final class FreshFindsViewModel: ObservableObject {
    /// Ready-to-show cards (photo loaded). Index 0 is the top card.
    @Published private(set) var cards: [FreshFind] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isExhausted = false
    /// Lowercased ids of every place the user already has (lists, favorites, my places) plus
    /// anything saved from this deck. Used to hide those places and to make saving idempotent.
    @Published private(set) var savedPlaceIds: Set<String> = []

    private let postService = SupabasePostService.shared
    private let pageSize = 30
    private var offset = 0
    private var hasMorePages = true
    private var pending: [ExploreVideoItem] = []
    private var seenPlaceIds = Set<String>()
    private var isFilling = false
    private(set) var swipeCount = 0
    private(set) var skippedForPhoto = 0

    /// Keep this many loaded cards ahead of the user.
    private let bufferTarget = 4

    func start(userId: String?) async {
        guard cards.isEmpty, !isFilling else { return }
        await loadSavedPlaceIds(userId: userId)
        await fill()
        isLoading = false
        Analytics.track(.discoveryViewed, ["cards_ready": cards.count, "skipped_no_photo": skippedForPhoto])
        if cards.isEmpty { Analytics.track(.discoveryEmpty, ["skipped_no_photo": skippedForPhoto]) }
    }

    /// Removes the top card after a swipe and tops the buffer back up.
    func swipe(_ card: FreshFind, direction: String) {
        cards.removeAll { $0.id == card.id }
        swipeCount += 1
        Analytics.track(.discoverySwiped, [
            "direction": direction,
            "place_id": card.item.placeId,
            "source": card.item.source,
            "position": swipeCount
        ])
        Task { await fill() }
    }

    /// Saves the card's place unless the user already has it. Returns true only when a new save
    /// happened (so the caller shows the "Saved" toast); already-saved places are a silent no-op.
    func save(_ card: FreshFind, userId: String?, via: String) async -> Bool {
        guard let userId, !userId.isEmpty else { return false }
        let key = Self.key(card.item.placeId)
        guard !savedPlaceIds.contains(key) else { return false }
        savedPlaceIds.insert(key)
        let result = await FavoritesService.shared.addFavorite(userId: userId, placeId: card.item.placeId)
        switch result {
        case .success:
            Analytics.track(.discoverySaved, ["place_id": card.item.placeId, "via": via, "position": swipeCount])
            return true
        case .duplicate:
            return false
        case .error:
            savedPlaceIds.remove(key)
            return false
        }
    }

    /// Normalizes a place id for set membership (ids differ in case between tables).
    private static func key(_ placeId: String) -> String { placeId.lowercased() }

    /// Loads the ids of all places the user already has; on failure the deck still works
    /// (the save path stays idempotent via the server-side duplicate check).
    private func loadSavedPlaceIds(userId: String?) async {
        guard let userId, !userId.isEmpty else { return }
        do {
            let places = try await SupabasePlaceService.shared.fetchAllUserPlaces(userId: userId)
            savedPlaceIds.formUnion(places.map { Self.key($0.id.uuidString) })
        } catch {
            print("⚠️ [FreshFinds] could not load saved places: \(error)")
        }
    }

    // MARK: - Loading

    private func fill() async {
        guard !isFilling else { return }
        isFilling = true
        defer { isFilling = false }

        while cards.count < bufferTarget {
            if pending.isEmpty {
                guard hasMorePages else { break }
                await fetchPage()
                if pending.isEmpty && !hasMorePages { break }
                continue
            }
            // Load a small batch of photos in parallel, keep feed order.
            let batch = Array(pending.prefix(4))
            pending.removeFirst(batch.count)
            let loaded = await withTaskGroup(of: (Int, UIImage?).self) { group -> [Int: UIImage] in
                for (i, item) in batch.enumerated() {
                    group.addTask { (i, await Self.loadPhoto(for: item)) }
                }
                var out: [Int: UIImage] = [:]
                for await (i, img) in group { if let img { out[i] = img } }
                return out
            }
            for (i, item) in batch.enumerated() where !savedPlaceIds.contains(Self.key(item.placeId)) {
                if let img = loaded[i] {
                    cards.append(FreshFind(item: item, image: img))
                } else {
                    skippedForPhoto += 1
                }
            }
        }
        isExhausted = cards.isEmpty && pending.isEmpty && !hasMorePages
    }

    private func fetchPage() async {
        do {
            let items = try await postService.fetchExploreVideos(limit: pageSize, offset: offset, city: nil)
            offset += items.count
            hasMorePages = items.count == pageSize
            for item in items where !seenPlaceIds.contains(item.placeId) {
                seenPlaceIds.insert(item.placeId)
                pending.append(item)
            }
        } catch {
            print("❌ [FreshFinds] page load failed: \(error)")
            hasMorePages = false
        }
    }

    /// Place photo first (stored review photo), then the video thumbnail. nil = skip the card.
    nonisolated private static func loadPhoto(for item: ExploreVideoItem) async -> UIImage? {
        let target = CGSize(width: 900, height: 1200)
        for candidate in [item.placePhotoUrl, item.thumbnailUrl] {
            guard let s = candidate, !s.isEmpty, let url = URL(string: s) else { continue }
            if let img = await ImageCacheService.shared.fetchImage(for: url, targetSize: target),
               img.size.width > 1 {
                return img
            }
        }
        return nil
    }
}
