//
//  TonightRanker.swift
//  loc
//
//  Pure, stateless ranking for Tonight. No network: everything it needs is
//  passed in, so it is cheap to re-run when the user changes the vibe chip
//  and easy to unit test.
//
//  score = 0.35 * vibe fit      (TonightCategoryClassifier.fit: 0.7...1.0)
//        + 0.30 * proximity     (1 / (1 + meters / 1200))
//        + 0.15 * open now      (open 1.0, unknown hours 0.6, closing soon 0.5)
//        + 0.20 * social proof  (you saved it +0.4, each friend who saved it +0.35, capped at 1)
//  Eligibility (hard rules, never relaxed to fill slots):
//    * Only food & drink places (by category; names only rescue places whose
//      categories are missing or generic). Shops, parks, museums, services: out.
//    * Must fit the vibe per TonightCategoryClassifier (Dinner = restaurants only,
//      Coffee = cafes/coffee shops only, Drinks = bars, Lunch = no bars/nightlife...).
//    * Closed right now, temporarily/permanently closed, or > 50 km: out.
//  If fewer than 3 eligible places are nearby the radius widens
//  (3 km -> 8 km -> 20 km -> 50 km); if still fewer, fewer picks are shown.
//

import Foundation
import CoreLocation

struct TonightRanker {
    static let maxDistanceMeters: Double = 50_000
    /// Search radii tried in order until `resultCount` eligible picks are found.
    static let radiusSteps: [Double] = [3_000, 8_000, 20_000, 50_000]
    static let resultCount = 3

    /// Generic category labels that say nothing about a place's vibe.
    static let genericCategories: Set<String> = [
        "restaurant", "restaurants", "food", "point_of_interest", "point of interest",
        "establishment", "store", "premise", "place", "meal takeaway", "meal delivery"
    ]

    let vibe: TonightVibe
    let origin: CLLocation?
    let currentUserId: String
    /// Lowercased friend id -> first name.
    let friendNames: [String: String]
    var usesMetric: Bool = Locale.current.measurementSystem != .us
    var openStatus: (DetailPlace) -> OpenStatus = { OpenStatusService.getStatus(for: $0) }

    /// Returns up to `limit` eligible picks, widening the radius until enough are found.
    func rank(candidates: [TonightCandidate], places: [String: DetailPlace], limit: Int = TonightRanker.resultCount) -> [TonightPick] {
        var eligible: [TonightPick] = []
        for candidate in candidates {
            guard let place = places[candidate.placeId.lowercased()] else { continue }
            let evaluation = evaluate(candidate: candidate, place: place)
            if evaluation.tier == .preferred { eligible.append(evaluation.pick) }
        }
        for radius in Self.radiusSteps {
            let within = eligible.filter { ($0.distanceMeters ?? 0) <= radius }
            if within.count >= limit { return Array(within.sorted(by: Self.ordering).prefix(limit)) }
        }
        return Array(eligible.sorted(by: Self.ordering).prefix(limit))
    }

    /// When nothing is open: eligible places that are only closed for now, soonest opening first,
    /// with an "Opens 8 AM" reason. Uses each place's own time zone.
    func openingLater(candidates: [TonightCandidate], places: [String: DetailPlace], limit: Int = TonightRanker.resultCount) -> [TonightPick] {
        var out: [(Date, TonightPick)] = []
        for candidate in candidates {
            guard let place = places[candidate.placeId.lowercased()] else { continue }
            let status = openStatus(place)
            switch status { case .closed, .openingSoon: break; default: continue }
            if !Self.isFoodOrDrink(place) || vibeScore(for: place) <= 0 { continue }
            let distance = distanceMeters(to: place)
            if let distance, distance > Self.radiusSteps[1] { continue }
            guard let lines = place.openHours, let hours = PlaceHours(weekdayText: lines) else { continue }
            let tz = PlaceTimeZoneCache.shared.timeZone(for: place.id.uuidString)
            let state = hours.state(at: Date(), timeZone: tz)
            guard !state.isOpen, let next = state.nextChange, next.timeIntervalSinceNow < 18 * 3600 else { continue }
            let opens = PlaceHours.changeText(for: state, timeZone: tz) ?? "Opens later"
            let base = evaluate(candidate: candidate, place: place).pick
            out.append((next, TonightPick(placeId: base.placeId, place: place, distanceMeters: distance,
                                          isOpenNow: false, score: base.score, reason: opens)))
        }
        return out.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1.score > $1.1.score }.prefix(limit).map(\.1)
    }

    // MARK: - Scoring

    /// `.fallback` is no longer produced: ineligible places are never used to fill slots.
    enum Tier { case preferred, fallback, excluded }

    /// Scores a single candidate and decides whether it is eligible.
    func evaluate(candidate: TonightCandidate, place: DetailPlace) -> (pick: TonightPick, tier: Tier) {
        let distance = distanceMeters(to: place)
        let status = openStatus(place)
        let vibeFit = vibeScore(for: place)
        let social = socialScore(saverIds: candidate.saverIds)

        let proximity: Double = distance.map { 1.0 / (1.0 + $0 / 1200.0) } ?? 0.5
        let openScore: Double
        var hardClosed = false
        switch status {
        case .open, .alwaysOpen: openScore = 1.0
        case .closingSoon: openScore = 0.5
        case .openingSoon: openScore = 0.4
        case .unknown: openScore = 0.6
        case .closed, .temporarilyClosed, .permanentlyClosed:
            openScore = 0
            hardClosed = true
        }

        let score = 0.35 * vibeFit + 0.30 * proximity + 0.15 * openScore + 0.20 * social
        let pick = TonightPick(
            placeId: candidate.placeId,
            place: place,
            distanceMeters: distance,
            isOpenNow: status == .unknown ? nil : status.isOpen,
            score: score,
            reason: reason(for: place, saverIds: candidate.saverIds, distance: distance, status: status)
        )

        if case .permanentlyClosed = status { return (pick, .excluded) }
        if case .temporarilyClosed = status { return (pick, .excluded) }
        if let distance, distance > Self.maxDistanceMeters { return (pick, .excluded) }
        if !Self.isFoodOrDrink(place) { return (pick, .excluded) }
        if hardClosed || vibeFit <= 0 { return (pick, .excluded) }
        return (pick, .preferred)
    }

    /// Returns 0...1 for how well the place fits the vibe (0 = not eligible). See TonightCategoryClassifier.
    func vibeScore(for place: DetailPlace) -> Double {
        TonightCategoryClassifier.fit(place, vibe: vibe)
    }

    // MARK: - Food & drink eligibility

    /// True when the place is a restaurant, cafe, bar, bakery, etc. Shops, services, parks and
    /// museums are excluded. Places with only generic categories qualify by name only.
    static func isFoodOrDrink(_ place: DetailPlace) -> Bool {
        !TonightCategoryClassifier.kinds(for: place).isEmpty
    }

    /// Joins strings into whole-word form (" wine bar | barber shop ").
    static func tokenText(_ pieces: [String]) -> String {
        pieces.map { TonightCategoryClassifier.tokenText($0) }.joined(separator: "|")
    }

    static func matches(_ tokenText: String, _ keyword: String) -> Bool {
        TonightCategoryClassifier.matches(tokenText, keyword)
    }

    /// Returns 0...1 social proof: the user's own save counts, each friend who saved it counts more.
    func socialScore(saverIds: Set<String>) -> Double {
        let me = currentUserId.lowercased()
        let mine = saverIds.contains(me) ? 0.4 : 0
        let friends = Double(saverIds.filter { $0 != me }.count) * 0.35
        return min(1.0, mine + friends)
    }

    /// Returns the straight-line distance from the origin to the place, if both are known.
    func distanceMeters(to place: DetailPlace) -> Double? {
        guard let origin, let coordinate = place.coordinate else { return nil }
        return origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    // MARK: - Reason

    /// Builds the one-line "why" shown under each pick, e.g. "Grace saved this · Cocktail bar · 6 min walk".
    func reason(for place: DetailPlace, saverIds: Set<String>, distance: Double?, status: OpenStatus) -> String {
        var parts: [String] = []
        let me = currentUserId.lowercased()
        let friendIds = saverIds.filter { $0 != me }.sorted()
        let names = friendIds.compactMap { friendNames[$0] }.filter { !$0.isEmpty }
        if let first = names.first {
            let others = friendIds.count - 1
            parts.append(others > 0 ? "\(first) + \(others) friend\(others == 1 ? "" : "s") saved this" : "\(first) saved this")
        } else if !friendIds.isEmpty {
            parts.append("\(friendIds.count) friend\(friendIds.count == 1 ? "" : "s") saved this")
        } else if saverIds.contains(me) {
            parts.append("From your saves")
        }
        if let category = Self.displayCategory(for: place) {
            parts.append(category)
        }
        if let distance {
            parts.append(Self.formatDistance(distance, metric: usesMetric))
        }
        switch status {
        case .closingSoon, .openingSoon:
            parts.append(status.displayText)
        case .open, .alwaysOpen:
            if parts.count < 3 { parts.append("Open now") }
        default:
            break
        }
        return parts.prefix(3).joined(separator: " · ")
    }

    // MARK: - Helpers

    /// Returns lowercased, joined category text (kept for callers/debugging).
    static func categoryText(for place: DetailPlace) -> String {
        TonightCategoryClassifier.categoryPieces(for: place).joined(separator: " | ")
    }

    /// Returns the first non-generic category, human-cased ("wine_bar" -> "Wine bar").
    static func displayCategory(for place: DetailPlace) -> String? {
        let pieces = ([place.userCorrectedCategory].compactMap { $0 }) + (place.categories ?? [])
        guard let raw = pieces.first(where: { !genericCategories.contains($0.lowercased()) && !$0.isEmpty }) else { return nil }
        let words = raw.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// Formats a distance as walking minutes when close, otherwise miles or kilometers.
    static func formatDistance(_ meters: Double, metric: Bool) -> String {
        if meters < 1600 {
            let minutes = max(1, Int((meters / 80).rounded()))
            return "\(minutes) min walk"
        }
        if metric {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.1f mi", meters / 1609.34)
    }

    /// Orders picks by score, breaking ties by distance.
    static func ordering(_ a: TonightPick, _ b: TonightPick) -> Bool {
        if a.score != b.score { return a.score > b.score }
        return (a.distanceMeters ?? .greatestFiniteMagnitude) < (b.distanceMeters ?? .greatestFiniteMagnitude)
    }
}
