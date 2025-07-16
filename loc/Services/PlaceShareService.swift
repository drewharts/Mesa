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
        sharePlace(shareablePlace)
    }
    
    @MainActor
    func sharePlace(_ nearbyPlace: NearbyPlaceFeature) {
        let shareablePlace = ShareablePlace(from: nearbyPlace)
        sharePlace(shareablePlace)
    }
    
    @MainActor
    private func sharePlace(_ shareablePlace: ShareablePlace) {
        guard let deepLinkURL = shareablePlace.deepLinkURL else {
            print("❌ Failed to generate deep link URL for place: \(shareablePlace.name)")
            return
        }
        
        let shareText = createShareText(for: shareablePlace)
        let activityItems: [Any] = [shareText, deepLinkURL]
        
        presentShareSheet(with: activityItems)
    }
    
    // MARK: - Share List Methods
    
    @MainActor
    func shareList(_ placeList: PlaceList, userId: String) {
        let shareableList = ShareableList(from: placeList, userId: userId)
        
        guard let deepLinkURL = shareableList.deepLinkURL else {
            print("❌ Failed to generate deep link URL for list: \(shareableList.name)")
            return
        }
        
        let shareText = createShareText(for: shareableList)
        let activityItems: [Any] = [shareText, deepLinkURL]
        
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
        
        shareText += " on Loc!"
        return shareText
    }
    
    private func createShareText(for list: ShareableList) -> String {
        var shareText = "Check out my list \"\(list.name)\""
        
        if !list.city.isEmpty {
            shareText += " in \(list.city)"
        }
        
        shareText += " on Loc!"
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
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
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