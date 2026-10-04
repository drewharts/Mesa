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
        let key = "trip_\(annotation.placeType ?? "")_\(colorKey)_\(annotation.stopNumber)_\(isSelected)"
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
