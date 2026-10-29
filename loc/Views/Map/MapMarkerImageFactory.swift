//
//  MapMarkerImageFactory.swift
//  loc
//
//  Renders the app's SwiftUI marker views into cached, static UIImages for use as
//  GMSMarker.icon (see GoogleMapView). Caching is keyed by visual variant
//  (emoji/size/selection), not by annotation instance, so the cache stays small
//  regardless of pin count.
//

import SwiftUI
import UIKit

@MainActor
final class MapMarkerImageFactory {
    static let shared = MapMarkerImageFactory()

    /// Transparent margin added around every rendered marker's content before it's flattened
    /// to a UIImage. ImageRenderer sizes its canvas exactly to the view's content, so any
    /// shadow/blur that extends past that content's edge gets hard-clipped by the canvas —
    /// visible as a faint rectangular halo behind an otherwise-circular marker. This padding
    /// gives every marker's shadow room to fade out fully within the canvas instead. Callers
    /// that anchor a marker by GMSMarker.groundAnchor must account for this (see GoogleMapView).
    static let renderPadding: CGFloat = 12

    private var cache: [String: UIImage] = [:]

    private init() {}

    private struct StatusDotKey: Hashable { let base: ObjectIdentifier; let isOpen: Bool }
    /// Holds the base image too, so its ObjectIdentifier can't be recycled by a different image.
    private var openDotCache: [StatusDotKey: (base: UIImage, image: UIImage)] = [:]

    /// Adds a small green "open now" dot at the top-right edge of a round marker image.
    func withOpenDot(_ base: UIImage) -> UIImage { withStatusDot(base, isOpen: true) }

    /// Badge in the pin's top-right: green when open now, gray when closed.
    func withStatusDot(_ base: UIImage, isOpen: Bool) -> UIImage {
        let key = StatusDotKey(base: ObjectIdentifier(base), isOpen: isOpen)
        if let cached = openDotCache[key], cached.base === base { return cached.image }
        let pad = Self.renderPadding
        let size = base.size
        let content = CGRect(origin: .zero, size: size).insetBy(dx: pad, dy: pad)
        let radius = min(content.width, content.height) / 2
        let center = CGPoint(x: content.midX + radius * 0.707, y: content.midY - radius * 0.707)
        let dot: CGFloat = 11
        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            base.draw(at: .zero)
            let rect = CGRect(x: center.x - dot / 2, y: center.y - dot / 2, width: dot, height: dot)
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: rect)
            (isOpen ? UIColor.systemGreen : UIColor.systemGray).setFill()
            ctx.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
        }
        if openDotCache.count > 500 { openDotCache.removeAll() }
        openDotCache[key] = (base, image)
        return image
    }

    /// Emoji-in-white-circle fallback marker, used when no profile-photo composite is available.
    func emojiCircleImage(placeType: String, isSelected: Bool) -> UIImage {
        let key = "emoji_\(placeType)_\(isSelected)"
        if let cached = cache[key] { return cached }
        let image = render(EmojiCircleMarkerContent(placeType: placeType, isSelected: isSelected))
        cache[key] = image
        return image
    }

    /// Community place marker. Always rendered in its non-selected/non-pulsing state —
    /// the selected pulsing-ring look is applied natively, not baked into an image.
    func communityMarkerImage(emoji: String, fontSize: CGFloat) -> UIImage {
        let key = "community_\(emoji)_\(Int(fontSize))"
        if let cached = cache[key] { return cached }
        let image = render(CommunityMarkerView(emoji: emoji, fontSize: fontSize, isSelected: false))
        cache[key] = image
        return image
    }

    /// City-level capsule marker showing the city name.
    func cityCapsuleImage(city: CityAnnotation, isSelected: Bool) -> UIImage {
        let key = "city_\(city.name)_\(isSelected)"
        if let cached = cache[key] { return cached }
        let image = render(CityAnnotationMarkerView(city: city, isSelected: isSelected))
        cache[key] = image
        return image
    }

    /// Trip itinerary pin, colored per day with a numbered stop badge.
    func tripPinImage(annotation: TripMapAnnotation, isSelected: Bool) -> UIImage {
        let colorKey = annotation.color.description
        let key = "trip_\(annotation.placeType ?? "")_\(colorKey)_\(annotation.stopNumber)_\(annotation.isVisited)_\(isSelected)"
        if let cached = cache[key] { return cached }
        let image = render(TripItineraryPinView(annotation: annotation, isSelected: isSelected, onTap: {}))
        cache[key] = image
        return image
    }

    /// Cluster bubble showing a member count, cached by count so it doesn't grow unbounded.
    func clusterImage(count: Int) -> UIImage {
        let bucket = min(count, 99)
        let key = "cluster_\(bucket)"
        if let cached = cache[key] { return cached }
        let image = render(ClusterBadgeView(count: bucket))
        cache[key] = image
        return image
    }

    /// User location dot, baked once and reused for the lifetime of the app.
    func userLocationDotImage() -> UIImage {
        let key = "user_location_dot"
        if let cached = cache[key] { return cached }
        let image = render(
            Circle()
                .fill(Color.blue)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 18, height: 18)
                )
                .shadow(radius: 4)
        )
        cache[key] = image
        return image
    }

    /// Snapshots a SwiftUI view hierarchy into a UIImage. Must run on the main actor —
    /// ImageRenderer relies on live UIView/CALayer rendering internally. Pads the content
    /// first so shadows have room to fade out inside the canvas (see renderPadding).
    private func render<V: View>(_ view: V) -> UIImage {
        let renderer = ImageRenderer(content: view.padding(Self.renderPadding))
        renderer.scale = 3
        renderer.isOpaque = false
        return renderer.uiImage ?? UIImage()
    }
}
