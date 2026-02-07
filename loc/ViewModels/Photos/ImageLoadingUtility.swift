//
//  ImageLoadingUtility.swift
//  loc
//
//  Shared image loading utilities used by photo ViewModels.
//

import Foundation
import UIKit

enum ImageLoadingUtility {
    /// Transforms a Google CDN URL to request higher resolution.
    static func getHighResGoogleURL(_ imageUrl: String, maxSize: Int = 1600) -> String {
        guard imageUrl.contains("lh3.googleusercontent.com") else {
            return imageUrl
        }

        var baseUrl = imageUrl
        if let range = baseUrl.range(of: "=s\\d+.*$", options: .regularExpression) {
            baseUrl.removeSubrange(range)
        }
        if let range = baseUrl.range(of: "=w\\d+-h\\d+.*$", options: .regularExpression) {
            baseUrl.removeSubrange(range)
        }

        return "\(baseUrl)=s\(maxSize)"
    }

    /// Loads an image from a URL, blocking legacy Firebase URLs and upgrading Google CDN resolution.
    static func loadImageFromURL(imageUrl: String) async -> UIImage? {
        if imageUrl.contains("firebasestorage.googleapis.com") {
            return nil
        }

        let highResUrl = getHighResGoogleURL(imageUrl, maxSize: 1600)

        guard let url = URL(string: highResUrl) else { return nil }

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0
            config.timeoutIntervalForResource = 10.0
            let session = URLSession(configuration: config)

            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return nil
            }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
