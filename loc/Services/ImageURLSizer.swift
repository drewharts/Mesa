//
//  ImageURLSizer.swift
//  loc
//
//  Single Responsibility: rewrite remote image URLs so the server returns a right-sized image
//  (cards and collage cells need a few hundred pixels, not the full-resolution original).
//  Unknown hosts pass through untouched.
//

import Foundation

enum ImageURLSizer {
    private static let buckets: [Int] = [200, 320, 480, 640, 960, 1280, 1600]
    private static let transformsDisabledKey = "imageSizer.storageTransformsDisabled"

    /// Returns a URL for the same image at roughly `maxPixel` on its longest side (bucketed so URLs repeat and cache well).
    static func sizedURL(_ url: URL, maxPixel: CGFloat) -> URL {
        let pixels = bucket(for: maxPixel)
        let host = url.host?.lowercased() ?? ""
        if host.hasSuffix("googleusercontent.com") { return googleCDN(url, pixels: pixels) }
        if host == "maps.googleapis.com", url.path.contains("/place/photo") { return placesLegacy(url, pixels: pixels) }
        if host == "places.googleapis.com", url.path.hasSuffix("/media") { return placesNew(url, pixels: pixels) }
        if host.hasSuffix("supabase.co"), url.path.contains("/storage/v1/object/public/") { return storageRender(url, pixels: pixels) }
        return url
    }

    /// Stops using Supabase image transforms after the server rejected one (e.g. the feature is not enabled).
    static func noteTransformRejected(_ sized: URL) {
        guard sized.path.contains("/storage/v1/render/image/") else { return }
        UserDefaults.standard.set(true, forKey: transformsDisabledKey)
    }

    // MARK: - Hosts

    /// lh3.googleusercontent.com links take a trailing `=s<px>` size suffix.
    private static func googleCDN(_ url: URL, pixels: Int) -> URL {
        var base = url.absoluteString
        if let range = base.range(of: "=[sw]\\d+[^/]*$", options: .regularExpression) {
            base.removeSubrange(range)
        }
        return URL(string: "\(base)=s\(pixels)") ?? url
    }

    /// Legacy Places photo links take `maxwidth` (and optionally `maxheight`); only the width is capped.
    private static func placesLegacy(_ url: URL, pixels: Int) -> URL {
        replacingQuery(of: url, remove: ["maxwidth", "maxheight"], add: [URLQueryItem(name: "maxwidth", value: String(pixels))])
    }

    /// Places API (New) media links take `maxWidthPx` / `maxHeightPx`.
    private static func placesNew(_ url: URL, pixels: Int) -> URL {
        replacingQuery(of: url, remove: ["maxwidthpx", "maxheightpx"], add: [URLQueryItem(name: "maxWidthPx", value: String(pixels))])
    }

    /// Public Supabase storage objects become render/image transforms (width + quality) unless transforms were rejected before.
    private static func storageRender(_ url: URL, pixels: Int) -> URL {
        guard !UserDefaults.standard.bool(forKey: transformsDisabledKey),
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        parts.path = parts.path.replacingOccurrences(of: "/storage/v1/object/public/", with: "/storage/v1/render/image/public/")
        var items = parts.queryItems ?? []
        items.removeAll { ["width", "quality"].contains($0.name.lowercased()) }
        items += [URLQueryItem(name: "width", value: String(pixels)), URLQueryItem(name: "quality", value: "70")]
        parts.queryItems = items
        return parts.url ?? url
    }

    // MARK: - Helpers

    /// Smallest bucket that covers the requested size.
    private static func bucket(for maxPixel: CGFloat) -> Int {
        buckets.first { CGFloat($0) >= maxPixel } ?? buckets[buckets.count - 1]
    }

    /// Returns the URL with the named query items (case-insensitive) swapped for the new ones.
    private static func replacingQuery(of url: URL, remove names: Set<String>, add: [URLQueryItem]) -> URL {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = parts.queryItems ?? []
        items.removeAll { names.contains($0.name.lowercased()) }
        parts.queryItems = items + add
        return parts.url ?? url
    }
}
