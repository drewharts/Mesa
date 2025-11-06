//
//  TikTokMetadataCache.swift
//  loc
//
//  Cache for TikTok oEmbed metadata to avoid redundant API calls
//

import Foundation

@MainActor
class TikTokMetadataCache: ObservableObject {
    static let shared = TikTokMetadataCache()
    
    // Cache mapping URL -> TikTokVideo metadata
    @Published private(set) var cache: [String: TikTokVideo] = [:]
    
    // Track URLs currently being fetched to avoid duplicate requests
    private var pendingRequests: Set<String> = []
    
    private let tikTokService = TikTokService()
    
    private init() {}
    
    /// Get TikTok metadata for a URL, fetching from backend if not cached
    func getMetadata(for url: String) async -> TikTokVideo? {
        // Return cached metadata if available
        if let cached = cache[url] {
            print("✅ [TikTokMetadataCache] Cache hit for URL: \(url)")
            return cached
        }
        
        // Avoid duplicate requests for the same URL
        if pendingRequests.contains(url) {
            print("⏳ [TikTokMetadataCache] Request already pending for URL: \(url)")
            // Wait a bit and check again
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return cache[url]
        }
        
        print("🔄 [TikTokMetadataCache] Cache miss - fetching metadata for URL: \(url)")
        pendingRequests.insert(url)
        
        defer {
            pendingRequests.remove(url)
        }
        
        // Fetch from backend
        let result = await tikTokService.getTikTokOEmbed(url: url)
        
        switch result {
        case .success(let oembedResponse):
            let tikTokVideo = oembedResponse.toTikTokVideo(videoUrl: url)
            cache[url] = tikTokVideo
            print("✅ [TikTokMetadataCache] Cached metadata for URL: \(url)")
            return tikTokVideo
            
        case .failure(let error):
            print("❌ [TikTokMetadataCache] Failed to fetch metadata: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get thumbnail URL for a TikTok video (convenience method)
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
    func getCachedMetadata(for url: String) -> TikTokVideo? {
        return cache[url]
    }
    
    /// Prefetch metadata for multiple URLs (useful for preloading)
    func prefetchMetadata(for urls: [String]) async {
        print("🔄 [TikTokMetadataCache] Prefetching metadata for \(urls.count) URLs")
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await self.getMetadata(for: url)
                }
            }
        }
        print("✅ [TikTokMetadataCache] Prefetch complete")
    }
    
    /// Clear the cache
    func clearCache() {
        cache.removeAll()
        pendingRequests.removeAll()
        print("🗑️ [TikTokMetadataCache] Cache cleared")
    }
    
    /// Remove specific URL from cache
    func removeFromCache(url: String) {
        cache.removeValue(forKey: url)
        print("🗑️ [TikTokMetadataCache] Removed URL from cache: \(url)")
    }
}

