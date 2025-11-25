//
//  TikTokVideoViewModel.swift
//  loc
//

import Foundation
import SwiftUI
import UIKit

// Debug logging flag - set to true for verbose logging, false for production
private let DEBUG_LOGGING = {
    #if DEBUG
        return true
    #else
        return false
    #endif
}()

func debugLog(_ message: String) {
    if DEBUG_LOGGING {
        print(message)
    }
}

@MainActor
class TikTokVideoViewModel: ObservableObject {
    @Published var tikTokVideo: TikTokVideo
    @Published var thumbnailLoadError: Bool = false
    @Published var hasAttemptedRefresh: Bool = false
    @Published var showingFullVideo = false
    
    private let tikTokService = TikTokService()
    private var isRefreshing: Bool = false
    private let externalPlaceId: String? // External place UUID for refresh
    
    init(tikTokVideo: TikTokVideo, externalPlaceId: String? = nil) {
        self.tikTokVideo = tikTokVideo
        self.externalPlaceId = externalPlaceId
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
            return 
        }
        
        isRefreshing = true
        hasAttemptedRefresh = true

        let userId = await SupabaseAuthService.shared.currentUserId
        
        // 🔍 Log what external_place_id we have before calling refresh
        debugLog("🎬 [TikTokVideoViewModel] Calling refreshThumbnail")
        debugLog("   Video ID: \(tikTokVideo.videoID)")
        debugLog("   External Place ID: \(externalPlaceId ?? "nil")")
        
        let result = await tikTokService.refreshTikTokThumbnail(
            for: tikTokVideo.url, 
            userId: userId,
            externalPlaceId: externalPlaceId
        )
        
        switch result {
        case .success(let newThumbnailURL):
            await handleSuccessfulThumbnailRefresh(newThumbnailURL)
        case .failure(let error):
            handleThumbnailRefreshError(error)
        }
        
        isRefreshing = false
    }
    
    private func handleSuccessfulThumbnailRefresh(_ newThumbnailURL: String) async {
        await testThumbnailURL(newThumbnailURL)
        updateTikTokVideoWithNewThumbnail(newThumbnailURL)
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
        debugLog("❌ [TikTokVideoViewModel] Thumbnail refresh failed: \(error.localizedDescription)")
    }

    private func testThumbnailURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                debugLog("❌ [TikTokVideoViewModel] Thumbnail URL returned status: \(httpResponse.statusCode)")
            }
        } catch {
            // URL test failed, but this is not critical - continue silently
        }
    }
    
    func resetRefreshState() {
        hasAttemptedRefresh = false
        thumbnailLoadError = false
    }
} 