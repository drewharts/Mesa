//
//  TikTokVideoViewModel.swift
//  loc
//

import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
class TikTokVideoViewModel: ObservableObject {
    @Published var tikTokVideo: TikTokVideo
    @Published var thumbnailLoadError: Bool = false
    @Published var hasAttemptedRefresh: Bool = false
    
    private let tikTokService = TikTokService()
    private var isRefreshing: Bool = false
    
    init(tikTokVideo: TikTokVideo) {
        self.tikTokVideo = tikTokVideo
    }
    
    func refreshThumbnail() async {
        // Prevent multiple simultaneous refresh attempts
        guard !isRefreshing && !hasAttemptedRefresh else { 
            print("⚠️ [TikTokVideoViewModel] Refresh blocked - isRefreshing: \(isRefreshing), hasAttemptedRefresh: \(hasAttemptedRefresh)")
            return 
        }
        
        print("🔄 [TikTokVideoViewModel] Starting refresh process for video: \(tikTokVideo.videoID)")
        print("🔄 [TikTokVideoViewModel] Current thumbnail URL: \(tikTokVideo.thumbnailURL)")
        
        isRefreshing = true
        hasAttemptedRefresh = true
        
        let userId = Auth.auth().currentUser?.uid
        print("🔄 [TikTokVideoViewModel] User ID: \(userId ?? "nil")")
        print("🔄 [TikTokVideoViewModel] Video URL to refresh: \(tikTokVideo.url)")
        
        let result = await tikTokService.refreshTikTokThumbnail(for: tikTokVideo.url, userId: userId)
        
        switch result {
        case .success(let newThumbnailURL):
            print("✅ [TikTokVideoViewModel] SUCCESS: Received new thumbnail URL: \(newThumbnailURL)")
            print("✅ [TikTokVideoViewModel] Old thumbnail URL was: \(tikTokVideo.thumbnailURL)")
            
            // Test if the new URL is actually accessible
            await testThumbnailURL(newThumbnailURL)
            
            // Create a new TikTokVideo struct with the updated thumbnail URL
            let updatedVideo = TikTokVideo(
                id: tikTokVideo.id,
                videoID: tikTokVideo.videoID,
                url: tikTokVideo.url,
                title: tikTokVideo.title,
                caption: tikTokVideo.caption,
                embedHTML: tikTokVideo.embedHTML,
                thumbnailURL: newThumbnailURL,
                author: tikTokVideo.author,
                hashtags: tikTokVideo.hashtags,
                createdAt: tikTokVideo.createdAt
            )
            
            // Replace the entire struct to trigger @Published updates
            tikTokVideo = updatedVideo
            thumbnailLoadError = false
            
            print("✅ [TikTokVideoViewModel] Updated tikTokVideo.thumbnailURL to: \(tikTokVideo.thumbnailURL)")
            print("✅ [TikTokVideoViewModel] thumbnailLoadError set to: \(thumbnailLoadError)")
            print("✅ [TikTokVideoViewModel] Replaced entire tikTokVideo struct to trigger @Published updates")
            
        case .failure(let error):
            print("❌ [TikTokVideoViewModel] FAILURE: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ [TikTokVideoViewModel] Error domain: \(nsError.domain)")
                print("❌ [TikTokVideoViewModel] Error code: \(nsError.code)")
                print("❌ [TikTokVideoViewModel] Error userInfo: \(nsError.userInfo)")
            }
        }
        
        isRefreshing = false
        print("🔄 [TikTokVideoViewModel] Refresh process completed. isRefreshing: \(isRefreshing)")
    }
    
    private func testThumbnailURL(_ urlString: String) async {
        print("🧪 [TikTokVideoViewModel] Testing thumbnail URL accessibility: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [TikTokVideoViewModel] Invalid URL format: \(urlString)")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🧪 [TikTokVideoViewModel] Thumbnail URL test - Status: \(httpResponse.statusCode)")
                print("🧪 [TikTokVideoViewModel] Thumbnail URL test - Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")
                print("🧪 [TikTokVideoViewModel] Thumbnail URL test - Content-Length: \(data.count) bytes")
                
                if httpResponse.statusCode == 200 {
                    print("✅ [TikTokVideoViewModel] Thumbnail URL is accessible!")
                } else {
                    print("❌ [TikTokVideoViewModel] Thumbnail URL returned status: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ [TikTokVideoViewModel] Failed to test thumbnail URL: \(error.localizedDescription)")
        }
    }
    
    func resetRefreshState() {
        print("🔄 [TikTokVideoViewModel] Resetting refresh state")
        hasAttemptedRefresh = false
        thumbnailLoadError = false
    }
} 