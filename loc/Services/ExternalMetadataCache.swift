//
//  ExternalMetadataCache.swift
//  loc
//
//  Cache for oEmbed metadata to avoid redundant API calls
//

import Foundation

@MainActor
class ExternalMetadataCache: ObservableObject {
    static let shared = ExternalMetadataCache()

    // Cache mapping URL -> ExternalVideo metadata
    @Published private(set) var cache: [String: ExternalVideo] = [:]

    // Track URLs currently being fetched to avoid duplicate requests
    private var pendingRequests: Set<String> = []

    private let externalContentService = ExternalContentService()

    private init() {}

    /// Get metadata for a URL, fetching from backend if not cached
    func getMetadata(for url: String) async -> ExternalVideo? {
        // Return cached metadata if available
        if let cached = cache[url] {
            return cached
        }

        // Avoid duplicate requests for the same URL
        if pendingRequests.contains(url) {
            // Wait a bit and check again
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return cache[url]
        }

        pendingRequests.insert(url)

        defer {
            pendingRequests.remove(url)
        }

        // Fetch from backend
        let result = await externalContentService.getTikTokOEmbed(url: url)

        switch result {
        case .success(let oembedResponse):
            let externalVideo = oembedResponse.toExternalVideo(videoUrl: url)
            cache[url] = externalVideo
            return externalVideo

        case .failure(let error):
            print("❌ [ExternalMetadataCache] Failed to fetch metadata: \(error.localizedDescription)")
            return nil
        }
    }

    /// Get thumbnail URL for a video (convenience method)
    func getThumbnailUrl(for url: String) async -> String? {
        guard let metadata = await getMetadata(for: url) else {
            return nil
        }
        return metadata.thumbnailURL
    }

    /// Get cached thumbnail URL synchronously (does not fetch, returns nil if not cached)
    func getCachedThumbnailUrl(for url: String) -> String? {
        return cache[url]?.thumbnailURL
    }

    /// Get cached metadata synchronously (does not fetch, returns nil if not cached)
    func getCachedMetadata(for url: String) -> ExternalVideo? {
        return cache[url]
    }

    /// Prefetch metadata for multiple URLs with concurrency limiting.
    func prefetchMetadata(for urls: [String]) async {
        // Limit concurrent requests to avoid socket exhaustion
        let maxConcurrent = 4

        // Process in batches to limit concurrent network requests
        for batch in urls.chunked(into: maxConcurrent) {
            await withTaskGroup(of: Void.self) { group in
                for url in batch {
                    group.addTask {
                        _ = await self.getMetadata(for: url)
                    }
                }
            }
        }
    }

    /// Clear the cache
    func clearCache() {
        cache.removeAll()
        pendingRequests.removeAll()
    }

    /// Remove specific URL from cache
    func removeFromCache(url: String) {
        cache.removeValue(forKey: url)
    }
}
