//
//  PlaceShareService.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import Foundation
import UIKit
import SwiftUI

class PlaceShareService: ObservableObject {
    
    // MARK: - Share Place Methods
    
    @MainActor
    func sharePlace(_ detailPlace: DetailPlace) {
        let shareablePlace = ShareablePlace(from: detailPlace)
        let imageURL = getFirstImageURL(from: detailPlace)
        sharePlace(shareablePlace, withImage: imageURL)
    }
    
    @MainActor
    func sharePlace(_ detailPlace: DetailPlace, withImage imageURL: String?) {
        let shareablePlace = ShareablePlace(from: detailPlace)
        sharePlace(shareablePlace, withImage: imageURL)
    }
    
    @MainActor
    func sharePlace(_ nearbyPlace: NearbyPlaceFeature) {
        let shareablePlace = ShareablePlace(from: nearbyPlace)
        sharePlace(shareablePlace)
    }
    
    @MainActor
    func sharePlace(_ nearbyPlace: NearbyPlaceFeature, withImage imageURL: String?) {
        let shareablePlace = ShareablePlace(from: nearbyPlace)
        sharePlace(shareablePlace, withImage: imageURL)
    }
    
    @MainActor
    private func sharePlace(_ shareablePlace: ShareablePlace) {
        guard shareablePlace.deepLinkURL != nil else {
            print("❌ Failed to generate deep link URL for place: \(shareablePlace.name)")
            return
        }
        
        // Generate web URL for rich previews
        let webURL = generateWebURL(for: shareablePlace)
        
        let shareText = createShareText(for: shareablePlace)
        let activityItems: [Any] = [shareText, webURL] // Share web URL for beautiful previews with auto-redirect
        
        presentShareSheet(with: activityItems)
    }
    
    @MainActor
    private func sharePlace(_ shareablePlace: ShareablePlace, withImage imageURL: String?) {
        guard shareablePlace.deepLinkURL != nil else {
            print("❌ Failed to generate deep link URL for place: \(shareablePlace.name)")
            return
        }
        
        // Generate web URL for rich previews with image
        let webURL = generateWebURL(for: shareablePlace, withImage: imageURL)
        
        let shareText = createShareText(for: shareablePlace)
        let activityItems: [Any] = [shareText, webURL] // Share web URL for beautiful previews with auto-redirect
        
        presentShareSheet(with: activityItems)
    }
    
    // MARK: - Share List Methods
    
    @MainActor
    func shareList(_ placeList: PlaceList, userId: String) {
        let shareableList = ShareableList(from: placeList, userId: userId)
        
        guard shareableList.deepLinkURL != nil else {
            print("❌ Failed to generate deep link URL for list: \(shareableList.name)")
            return
        }
        
        // Generate web URL for rich previews
        let webURL = generateWebURL(for: shareableList)
        
        let shareText = createShareText(for: shareableList)
        let activityItems: [Any] = [shareText, webURL] // Share web URL for beautiful previews with auto-redirect
        
        presentShareSheet(with: activityItems)
    }

    // MARK: - Share Text Generation
    
    private func createShareText(for place: ShareablePlace) -> String {
        var shareText = "Check out \(place.name)"
        
        if let address = place.address, !address.isEmpty {
            shareText += " at \(address)"
        } else if let city = place.city, !city.isEmpty {
            shareText += " in \(city)"
        }
        
        shareText += " on Mesa!"
        return shareText
    }
    
    private func createShareText(for list: ShareableList) -> String {
        var shareText = "Check out my list \"\(list.name)\""
        
        if !list.city.isEmpty {
            shareText += " in \(list.city)"
        }
        
        shareText += " on Mesa!"
        return shareText
    }
    
    // MARK: - Activity Sheet Presentation
    
    @MainActor
    private func presentShareSheet(with items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("❌ Could not find root view controller for share sheet")
            return
        }

        let topViewController = rootViewController.topMostViewController()
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = topViewController.view
            popover.sourceRect = CGRect(
                x: topViewController.view.bounds.midX,
                y: topViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        topViewController.present(activityViewController, animated: true)
    }
    
    // MARK: - URL Generation
    
    func generateShareURL(for detailPlace: DetailPlace) -> URL? {
        let shareablePlace = ShareablePlace(from: detailPlace)
        return shareablePlace.deepLinkURL
    }
    
    func generateShareURL(for nearbyPlace: NearbyPlaceFeature) -> URL? {
        let shareablePlace = ShareablePlace(from: nearbyPlace)
        return shareablePlace.deepLinkURL
    }
    
    // MARK: - Web URL Generation
    
    private func generateWebURL(for shareablePlace: ShareablePlace) -> URL {
        return generateWebURL(for: shareablePlace, withImage: nil)
    }
    
    private func generateWebURL(for shareablePlace: ShareablePlace, withImage imageURL: String?) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "us-central1-locc-7598c.cloudfunctions.net"
        components.path = "/serveWebPreview"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "type", value: "place"))
        queryItems.append(URLQueryItem(name: "id", value: shareablePlace.id))
        queryItems.append(URLQueryItem(name: "name", value: shareablePlace.name))
        
        if let address = shareablePlace.address {
            queryItems.append(URLQueryItem(name: "address", value: address))
        }
        
        if let city = shareablePlace.city {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }
        
        // Add mapboxId if available for better place identification
        if let mapboxId = shareablePlace.mapboxId {
            queryItems.append(URLQueryItem(name: "mapboxId", value: mapboxId))
        }
        
        // Add image URL if provided
        if let imageURL = imageURL {
            queryItems.append(URLQueryItem(name: "image", value: imageURL))
        }
        
        components.queryItems = queryItems
        return components.url ?? URL(string: "https://mesa-backend-production.up.railway.app")!
    }
    
    private func generateWebURL(for shareableList: ShareableList) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "us-central1-locc-7598c.cloudfunctions.net"
        components.path = "/serveWebPreview"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "type", value: "list"))
        queryItems.append(URLQueryItem(name: "id", value: shareableList.id))
        queryItems.append(URLQueryItem(name: "name", value: shareableList.name))
        queryItems.append(URLQueryItem(name: "city", value: shareableList.city))
        queryItems.append(URLQueryItem(name: "userId", value: shareableList.userId))
        
        components.queryItems = queryItems
        return components.url ?? URL(string: "https://mesa-backend-production.up.railway.app")!
    }
    
    // MARK: - Image Helpers
    
    private func getFirstImageURL(from detailPlace: DetailPlace) -> String? {
        // Try to get the first photo URL from the place
        if let photoUrls = detailPlace.photoUrls, !photoUrls.isEmpty {
            return photoUrls.first
        }
        
        // Try to get image from TikTok videos
        if let tikTokVideos = detailPlace.tikTokVideos, !tikTokVideos.isEmpty {
            return tikTokVideos.first?.thumbnailURL
        }
        
        return nil
    }
    
    private func getFirstImageURL(from nearbyPlace: NearbyPlaceFeature) -> String? {
        // For nearby places, we might not have images readily available
        // This could be enhanced by fetching place details
        return nil
    }
    
    // MARK: - Copy to Clipboard
    
    @MainActor
    func copyPlaceLink(_ detailPlace: DetailPlace) {
        guard let url = generateShareURL(for: detailPlace) else {
            print("❌ Failed to generate URL for place: \(detailPlace.name)")
            return
        }
        
        UIPasteboard.general.url = url
        print("✅ Copied place link to clipboard: \(url)")
    }
    
    @MainActor
    func copyPlaceLink(_ nearbyPlace: NearbyPlaceFeature) {
        guard let url = generateShareURL(for: nearbyPlace) else {
            print("❌ Failed to generate URL for place: \(nearbyPlace.properties.name)")
            return
        }
        
        UIPasteboard.general.url = url
        print("✅ Copied place link to clipboard: \(url)")
    }
} 