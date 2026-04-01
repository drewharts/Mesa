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
    
    // MARK: - Universal Links Base URL
    private let universalLinkHost = MesaBackendConfig.universalLinkHost
    
    // MARK: - Share Place Methods
    
    /// Shares a place with text and universal link.
    @MainActor
    func sharePlace(_ detailPlace: DetailPlace) {
        let shareablePlace = ShareablePlace(from: detailPlace)
        sharePlace(shareablePlace)
    }

    /// Shares a place (variant accepting unused imageURL for backward compatibility).
    @MainActor
    func sharePlace(_ detailPlace: DetailPlace, withImage imageURL: String?) {
        sharePlace(detailPlace)
    }

    /// Shares a nearby place with text and universal link.
    @MainActor
    func sharePlace(_ nearbyPlace: NearbyPlaceFeature) {
        let shareablePlace = ShareablePlace(from: nearbyPlace)
        sharePlace(shareablePlace)
    }

    /// Shares a nearby place (variant accepting unused imageURL for backward compatibility).
    @MainActor
    func sharePlace(_ nearbyPlace: NearbyPlaceFeature, withImage imageURL: String?) {
        sharePlace(nearbyPlace)
    }
    
    @MainActor
    private func sharePlace(_ shareablePlace: ShareablePlace) {
        guard let universalLink = generateUniversalLinkURL(for: shareablePlace) else {
            print("❌ Failed to generate Universal Link URL for place: \(shareablePlace.name)")
            return
        }
        
        let shareText = createShareText(for: shareablePlace)
        // Share Universal Link - opens app directly AND shows rich previews in messaging apps
        let activityItems: [Any] = [shareText, universalLink]
        
        presentShareSheet(with: activityItems)
    }
    
    // MARK: - Share List Methods
    
    @MainActor
    func shareList(_ placeList: PlaceList, userId: String) {
        let shareableList = ShareableList(from: placeList, userId: userId)
        
        guard let universalLink = generateUniversalLinkURL(for: shareableList) else {
            print("❌ Failed to generate Universal Link URL for list: \(shareableList.name)")
            return
        }
        
        let shareText = createShareText(for: shareableList)
        // Share Universal Link - opens app directly AND shows rich previews in messaging apps
        let activityItems: [Any] = [shareText, universalLink]
        
        presentShareSheet(with: activityItems)
    }
    
    @MainActor
    func shareLightweightList(_ lightweightList: LightweightPlaceList, userId: String) {
        let shareableList = ShareableLightweightList(from: lightweightList, userId: userId)

        guard let universalLink = generateUniversalLinkURL(for: shareableList) else {
            print("❌ Failed to generate Universal Link URL for list: \(shareableList.name)")
            return
        }

        let shareText = createShareText(for: shareableList)
        // Share Universal Link - opens app directly AND shows rich previews in messaging apps
        let activityItems: [Any] = [shareText, universalLink]
        presentShareSheet(with: activityItems)
    }

    // MARK: - Share Profile Methods

    @MainActor
    func shareProfile(_ profileData: ProfileData) {
        let shareableProfile = ShareableProfile(from: profileData)
        shareProfile(shareableProfile)
    }

    @MainActor
    func shareProfile(userId: String, fullName: String, profilePhotoURL: String?) {
        let shareableProfile = ShareableProfile(id: userId, fullName: fullName, profilePhotoURL: profilePhotoURL)
        shareProfile(shareableProfile)
    }

    @MainActor
    private func shareProfile(_ shareableProfile: ShareableProfile) {
        guard let universalLink = generateUniversalLinkURL(for: shareableProfile) else {
            print("❌ Failed to generate Universal Link URL for profile: \(shareableProfile.fullName)")
            return
        }

        let shareText = createShareText(for: shareableProfile)
        let activityItems: [Any] = [shareText, universalLink]

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
    
    private func createShareText(for list: ShareableLightweightList) -> String {
        var shareText = "Check out my list \"\(list.name)\""

        if !list.city.isEmpty {
            shareText += " in \(list.city)"
        }

        shareText += " on Mesa!"
        return shareText
    }

    private func createShareText(for profile: ShareableProfile) -> String {
        if profile.fullName.isEmpty {
            return "Check out this profile on Mesa!"
        }
        return "Check out \(profile.fullName)'s profile on Mesa!"
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
        return generateUniversalLinkURL(for: shareablePlace)
    }
    
    func generateShareURL(for nearbyPlace: NearbyPlaceFeature) -> URL? {
        let shareablePlace = ShareablePlace(from: nearbyPlace)
        return generateUniversalLinkURL(for: shareablePlace)
    }
    
    // MARK: - Universal Link URL Generation
    
    /// Generates a Universal Link URL for a place
    /// Format: https://us-central1-locc-7598c.cloudfunctions.net/place/[id]?name=...&address=...
    private func generateUniversalLinkURL(for shareablePlace: ShareablePlace) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = universalLinkHost
        components.path = "/place/\(shareablePlace.id)"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: shareablePlace.name))
        
        if let address = shareablePlace.address {
            queryItems.append(URLQueryItem(name: "address", value: address))
        }
        
        if let city = shareablePlace.city {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }
        
        if let mapboxId = shareablePlace.mapboxId {
            queryItems.append(URLQueryItem(name: "mapboxId", value: mapboxId))
        }
        
        if let lat = shareablePlace.latitude {
            queryItems.append(URLQueryItem(name: "lat", value: String(lat)))
        }
        
        if let lng = shareablePlace.longitude {
            queryItems.append(URLQueryItem(name: "lng", value: String(lng)))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    /// Generates a Universal Link URL for a list
    /// Format: https://us-central1-locc-7598c.cloudfunctions.net/list/[id]?name=...&city=...&userId=...
    private func generateUniversalLinkURL(for shareableList: ShareableList) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = universalLinkHost
        components.path = "/list/\(shareableList.id)"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: shareableList.name))
        queryItems.append(URLQueryItem(name: "city", value: shareableList.city))
        queryItems.append(URLQueryItem(name: "userId", value: shareableList.userId))
        
        components.queryItems = queryItems
        return components.url
    }
    
    /// Generates a Universal Link URL for a lightweight list
    private func generateUniversalLinkURL(for shareableList: ShareableLightweightList) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = universalLinkHost
        components.path = "/list/\(shareableList.id)"

        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: shareableList.name))
        queryItems.append(URLQueryItem(name: "city", value: shareableList.city))
        queryItems.append(URLQueryItem(name: "userId", value: shareableList.userId))

        components.queryItems = queryItems
        return components.url
    }

    /// Generates a Universal Link URL for a profile
    /// Format: https://mesa.drewharts.com/profile/[userId]?name=...
    private func generateUniversalLinkURL(for profile: ShareableProfile) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = universalLinkHost
        components.path = "/profile/\(profile.id)"

        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: profile.fullName))

        if let photoURL = profile.profilePhotoURL {
            queryItems.append(URLQueryItem(name: "photoURL", value: photoURL))
        }

        components.queryItems = queryItems
        return components.url
    }

    // MARK: - Image Helpers
    
    private func getFirstImageURL(from detailPlace: DetailPlace) -> String? {
        // Try to get the first photo URL from the place
        if let photoUrls = detailPlace.photoUrls, !photoUrls.isEmpty {
            return photoUrls.first
        }
        
        // Try to get image from external videos
        if let externalVideos = detailPlace.externalVideos, !externalVideos.isEmpty {
            return externalVideos.first?.thumbnailURL
        }
        
        return nil
    }
    
    private func getFirstImageURL(from nearbyPlace: NearbyPlaceFeature) -> String? {
        // For nearby places, we might not have images readily available
        // This could be enhanced by fetching place details
        return nil
    }
    
    // MARK: - Share Image

    /// Shares an image via the system share sheet.
    @MainActor
    func shareImage(_ image: UIImage, with text: String? = nil) {
        var activityItems: [Any] = [image]

        if let shareText = text {
            activityItems.insert(shareText, at: 0)
        }

        presentShareSheet(with: activityItems)
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