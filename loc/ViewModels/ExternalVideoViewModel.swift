//
//  ExternalVideoViewModel.swift
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
class ExternalVideoViewModel: ObservableObject {
    @Published var externalVideo: ExternalVideo
    @Published var thumbnailLoadError: Bool = false
    @Published var hasAttemptedRefresh: Bool = false
    @Published var showingFullVideo = false
    
    private let externalContentService = ExternalContentService()
    private var isRefreshing: Bool = false
    private let externalPlaceId: String? // External place UUID for refresh
    
    init(externalVideo: ExternalVideo, externalPlaceId: String? = nil) {
        self.externalVideo = externalVideo
        self.externalPlaceId = externalPlaceId
    }
    
    // MARK: - Video Opening Logic
    
    /// Opens the external video content in the best available method.
    func openVideo() {
        if tryOpenInTikTokApp() { return }
        if tryOpenInBrowser() { return }
        // Only show embedded WebView if we have embed HTML (videos only, not photos)
        if !externalVideo.embedHTML.isEmpty {
            showFullVideoModal()
        }
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
        if let originalURL = URL(string: externalVideo.url) {
            urls.append(originalURL)
        }
    }
    
    /// Adds TikTok app deep link scheme URLs for the content type.
    private func addVideoSchemeURLs(to urls: inout [URL]) {
        guard let videoId = extractVideoId(from: externalVideo.url) else { return }

        let contentPath = externalVideo.contentType == "photo" ? "photo" : "video"
        let schemeURLs = [
            "tiktok://\(contentPath)/\(videoId)",
            "snssdk1233://\(contentPath)?id=\(videoId)"
        ]

        for urlString in schemeURLs {
            if let url = URL(string: urlString) {
                urls.append(url)
            }
        }
    }
    
    private func tryOpenInBrowser() -> Bool {
        guard let webURL = URL(string: externalVideo.url),
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
    
    /// Extracts the content ID from a regular TikTok URL (video or photo).
    private func extractFromRegularURL(_ urlString: String) -> String? {
        guard let range = urlString.range(of: "/video/") ?? urlString.range(of: "/photo/") else {
            return nil
        }

        let afterPath = String(urlString[range.upperBound...])
        return afterPath.components(separatedBy: "?").first?.components(separatedBy: "/").first
    }
    
    // MARK: - Thumbnail Management
    
    func refreshThumbnail() async {
        // Prevent multiple simultaneous refresh attempts
        guard !isRefreshing && !hasAttemptedRefresh else { 
            return 
        }
        
        isRefreshing = true
        hasAttemptedRefresh = true

        let userId = SupabaseAuthService.shared.currentUserId
        
        // 🔍 Log what external_place_id we have before calling refresh
        debugLog("🎬 [ExternalVideoViewModel] Calling refreshThumbnail")
        debugLog("   Video ID: \(externalVideo.videoID)")
        debugLog("   External Place ID: \(externalPlaceId ?? "nil")")
        
        let result = await externalContentService.refreshTikTokThumbnail(
            for: externalVideo.url, 
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
        updateExternalVideoWithNewThumbnail(newThumbnailURL)
    }
    
    /// Updates the external video with a refreshed thumbnail URL.
    private func updateExternalVideoWithNewThumbnail(_ newThumbnailURL: String) {
        let updatedVideo = ExternalVideo(
            id: externalVideo.id,
            videoID: externalVideo.videoID,
            url: externalVideo.url,
            title: externalVideo.title,
            caption: externalVideo.caption,
            embedHTML: externalVideo.embedHTML,
            thumbnailURL: newThumbnailURL,
            author: externalVideo.author,
            hashtags: externalVideo.hashtags,
            createdAt: externalVideo.createdAt,
            contentType: externalVideo.contentType
        )

        externalVideo = updatedVideo
        thumbnailLoadError = false
    }
    
    private func handleThumbnailRefreshError(_ error: Error) {
        debugLog("❌ [ExternalVideoViewModel] Thumbnail refresh failed: \(error.localizedDescription)")
    }

    private func testThumbnailURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                debugLog("❌ [ExternalVideoViewModel] Thumbnail URL returned status: \(httpResponse.statusCode)")
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
