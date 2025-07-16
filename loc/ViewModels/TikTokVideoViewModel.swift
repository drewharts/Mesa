//
//  TikTokVideoViewModel.swift
//  loc
//

import Foundation
import SwiftUI
import FirebaseAuth
import UIKit

@MainActor
class TikTokVideoViewModel: ObservableObject {
    @Published var tikTokVideo: TikTokVideo
    @Published var thumbnailLoadError: Bool = false
    @Published var hasAttemptedRefresh: Bool = false
    @Published var showingFullVideo = false
    
    private let tikTokService = TikTokService()
    private var isRefreshing: Bool = false
    
    init(tikTokVideo: TikTokVideo) {
        self.tikTokVideo = tikTokVideo
    }
    
    // MARK: - Video Opening Logic
    
    func openVideo() {
        if tryOpenInTikTokApp() { return }
        if tryOpenInBrowser() { return }
        showFullVideoModal()
    }
    
    private func showFullVideoModal() {
        showingFullVideo = true
    }
    
    private func tryOpenInTikTokApp() -> Bool {
        guard isTikTokAppInstalled() else { return false }
        
        let urlsToTry = createTikTokURLsToTry()
        return attemptToOpenURLs(urlsToTry)
    }
    
    private func isTikTokAppInstalled() -> Bool {
        guard let tiktokURL = URL(string: "tiktok://") else { return false }
        return UIApplication.shared.canOpenURL(tiktokURL)
    }
    
    private func attemptToOpenURLs(_ urls: [URL]) -> Bool {
        for url in urls {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return true
            }
        }
        return false
    }
    
    private func createTikTokURLsToTry() -> [URL] {
        var urls: [URL] = []
        
        addOriginalURL(to: &urls)
        addVideoSchemeURLs(to: &urls)
        
        return urls
    }
    
    private func addOriginalURL(to urls: inout [URL]) {
        if let originalURL = URL(string: tikTokVideo.url) {
            urls.append(originalURL)
        }
    }
    
    private func addVideoSchemeURLs(to urls: inout [URL]) {
        guard let videoId = extractVideoId(from: tikTokVideo.url) else { return }
        
        let schemeURLs = [
            "tiktok://video/\(videoId)",
            "snssdk1233://video?id=\(videoId)"
        ]
        
        for urlString in schemeURLs {
            if let url = URL(string: urlString) {
                urls.append(url)
            }
        }
    }
    
    private func tryOpenInBrowser() -> Bool {
        guard let webURL = URL(string: tikTokVideo.url),
              UIApplication.shared.canOpenURL(webURL) else {
            return false
        }
        UIApplication.shared.open(webURL)
        return true
    }
    
    // MARK: - Video ID Extraction
    
    private func extractVideoId(from urlString: String) -> String? {
        if let shortId = extractFromShortURL(urlString) {
            return shortId
        }
        return extractFromRegularURL(urlString)
    }
    
    private func extractFromShortURL(_ urlString: String) -> String? {
        guard urlString.contains("/t/"),
              let range = urlString.range(of: "/t/") else {
            return nil
        }
        
        return cleanVideoId(from: urlString, after: range.upperBound)
    }
    
    private func cleanVideoId(from urlString: String, after startIndex: String.Index) -> String? {
        let afterT = String(urlString[startIndex...])
        var videoId = removeTrailingSlash(from: afterT)
        videoId = removeQueryParameters(from: videoId)
        videoId = removeSpecialCharacters(from: videoId)
        
        return videoId.isEmpty ? nil : videoId
    }
    
    private func removeTrailingSlash(from string: String) -> String {
        if let endRange = string.range(of: "/") {
            return String(string[..<endRange.lowerBound])
        }
        return string
    }
    
    private func removeQueryParameters(from string: String) -> String {
        return string.components(separatedBy: "?").first ?? string
    }
    
    private func removeSpecialCharacters(from string: String) -> String {
        return string.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
    
    private func extractFromRegularURL(_ urlString: String) -> String? {
        guard urlString.contains("/video/"),
              let range = urlString.range(of: "/video/") else {
            return nil
        }
        
        let afterVideo = String(urlString[range.upperBound...])
        return afterVideo.components(separatedBy: "?").first?.components(separatedBy: "/").first
    }
    
    // MARK: - Thumbnail Management
    
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
            await handleSuccessfulThumbnailRefresh(newThumbnailURL)
        case .failure(let error):
            handleThumbnailRefreshError(error)
        }
        
        isRefreshing = false
        print("🔄 [TikTokVideoViewModel] Refresh process completed. isRefreshing: \(isRefreshing)")
    }
    
    private func handleSuccessfulThumbnailRefresh(_ newThumbnailURL: String) async {
        print("✅ [TikTokVideoViewModel] SUCCESS: Received new thumbnail URL: \(newThumbnailURL)")
        print("✅ [TikTokVideoViewModel] Old thumbnail URL was: \(tikTokVideo.thumbnailURL)")
        
        await testThumbnailURL(newThumbnailURL)
        updateTikTokVideoWithNewThumbnail(newThumbnailURL)
        
        print("✅ [TikTokVideoViewModel] Updated tikTokVideo.thumbnailURL to: \(tikTokVideo.thumbnailURL)")
        print("✅ [TikTokVideoViewModel] thumbnailLoadError set to: \(thumbnailLoadError)")
        print("✅ [TikTokVideoViewModel] Replaced entire tikTokVideo struct to trigger @Published updates")
    }
    
    private func updateTikTokVideoWithNewThumbnail(_ newThumbnailURL: String) {
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
        
        tikTokVideo = updatedVideo
        thumbnailLoadError = false
    }
    
    private func handleThumbnailRefreshError(_ error: Error) {
        print("❌ [TikTokVideoViewModel] FAILURE: \(error.localizedDescription)")
        if let nsError = error as NSError? {
            print("❌ [TikTokVideoViewModel] Error domain: \(nsError.domain)")
            print("❌ [TikTokVideoViewModel] Error code: \(nsError.code)")
            print("❌ [TikTokVideoViewModel] Error userInfo: \(nsError.userInfo)")
        }
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