//  PlaceCandidateRanker.swift
//  loc
//
//  Pure scoring of nearby place candidates for a photo cluster, plus the search-radius plan.

import Foundation

struct RankedPlaceCandidates {
    let places: [NearbyPlaceFeature]
    /// True only when the top candidate clearly beats the runner-up.
    let hasConfidentPick: Bool
}

enum PlaceCandidateRanker {
    static let visitTypeBonus = 25.0
    static let nonVisitPenalty = 60.0
    static let closedPenalty = 80.0
    static let permanentlyClosedPenalty = 500.0
    /// Minimum cost gap (meter-equivalents) between first and second for a confident pick.
    static let confidenceGap = 20.0
    /// A lone candidate is only a confident pick when it is this close.
    static let loneCandidateMaxDistance = 40.0

    static let visitTypes: Set<String> = [
        "restaurant", "bar", "cafe", "coffee_shop", "bakery", "night_club", "meal_takeaway",
        "meal_delivery", "food", "pub", "ice_cream_shop", "tourist_attraction", "museum",
        "park", "store", "shopping_mall", "movie_theater", "art_gallery", "brewery", "winery"
    ]
    static let nonVisitTypes: Set<String> = [
        "atm", "bank", "transit_station", "subway_station", "bus_station", "train_station",
        "parking", "route", "locality", "neighborhood", "premise", "street_address",
        "sublocality", "political", "administrative_area_level_1", "administrative_area_level_2",
        "postal_code", "intersection"
    ]

    /// Ranks candidates around a center, optionally accounting for opening hours at the capture time.
    static func rank(
        _ candidates: [NearbyPlaceFeature],
        centerLatitude: Double,
        centerLongitude: Double,
        capturedAt: Date? = nil,
        utcOffsetSeconds: Int? = nil
    ) -> RankedPlaceCandidates {
        let scored = candidates.enumerated().map { offset, place -> (NearbyPlaceFeature, Double, Double, Int) in
            let d = PhotoClusterBuilder.distanceMeters(
                centerLatitude, centerLongitude, place.geometry.latitude, place.geometry.longitude)
            let cost = d + typeAdjustment(place) + hoursAdjustment(place, capturedAt, utcOffsetSeconds)
            return (place, cost, d, offset)
        }.sorted { ($0.1, $0.3) < ($1.1, $1.3) }

        return RankedPlaceCandidates(places: scored.map(\.0), hasConfidentPick: isConfident(scored.map { ($0.1, $0.2) }))
    }

    /// Returns the cost adjustment for place types (negative favors, positive penalizes).
    static func typeAdjustment(_ place: NearbyPlaceFeature) -> Double {
        let types = Set(place.properties.types ?? [])
        var adjustment = 0.0
        if !types.isDisjoint(with: visitTypes) { adjustment -= visitTypeBonus }
        if !types.isDisjoint(with: nonVisitTypes) { adjustment += nonVisitPenalty }
        if place.properties.permanentlyClosed == true || place.properties.businessStatus == "CLOSED_PERMANENTLY" {
            adjustment += permanentlyClosedPenalty
        }
        return adjustment
    }

    /// Penalizes places known to be closed at the photo's local capture time.
    static func hoursAdjustment(_ place: NearbyPlaceFeature, _ date: Date?, _ offset: Int?) -> Double {
        guard let date, let hours = place.properties.regularOpeningHours,
              hours.isOpen(at: date, utcOffsetSeconds: offset ?? 0) == false else { return 0 }
        return closedPenalty
    }

    /// Decides whether the best (cost, distance) pair clearly wins over the rest.
    private static func isConfident(_ scored: [(cost: Double, distance: Double)]) -> Bool {
        guard let first = scored.first else { return false }
        guard scored.count > 1 else { return first.distance <= loneCandidateMaxDistance }
        return scored[1].cost - first.cost >= confidenceGap
    }

    /// Returns the expanding search radii (meters): accuracy-aware first step, then 150, capped at 300.
    static func searchRadii(bestAccuracyMeters: Double?) -> [Int] {
        var first = 60
        if let acc = bestAccuracyMeters, acc > 50 { first = Int(min(max(acc, 75), 150)) }
        return [first, 150, 300].reduce(into: [Int]()) { out, r in
            if out.last.map({ r > $0 }) ?? true { out.append(r) }
        }
    }
}
