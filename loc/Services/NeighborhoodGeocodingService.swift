//
//  NeighborhoodGeocodingService.swift
//  loc
//
//  Resolves a coordinate to its neighborhood name (e.g. "West Village") with CLGeocoder.
//  Requests are serialized by the caller (CLGeocoder cancels overlapping requests and Apple
//  rate-limits to roughly 50 per minute); this service backs off when the system says no.
//

import Foundation
import CoreLocation

@MainActor
final class NeighborhoodGeocodingService {
    static let shared = NeighborhoodGeocodingService()

    enum Outcome {
        /// The neighborhood was found.
        case found(String)
        /// The geocoder answered but has no neighborhood for this coordinate.
        case notFound
        /// The geocoder could not answer right now (offline, throttled). Try again later.
        case unavailable
    }

    private let geocoder = CLGeocoder()
    private var backoffUntil = Date.distantPast

    private init() {}

    /// Reverse-geocodes the coordinate and returns its neighborhood, if any.
    func neighborhood(latitude: Double, longitude: Double) async -> Outcome {
        guard Date() >= backoffUntil else { return .unavailable }
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: latitude, longitude: longitude)
            )
            if let name = placemarks.first?.subLocality?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return .found(name)
            }
            return .notFound
        } catch {
            if let clError = error as? CLError, clError.code == .geocodeFoundNoResult {
                return .notFound
            }
            backoffUntil = Date().addingTimeInterval(60)
            return .unavailable
        }
    }
}
