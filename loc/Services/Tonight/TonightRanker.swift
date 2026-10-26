//
//  TonightRanker.swift
//  loc
//
//  Pure, stateless ranking for Tonight. No network: everything it needs is
//  passed in, so it is cheap to re-run when the user changes the vibe chip
//  and easy to unit test.
//
//  score = 0.35 * vibe fit      (place categories vs. the vibe's keywords)
//        + 0.30 * proximity     (1 / (1 + meters / 1200))
//        + 0.15 * open now      (open 1.0, unknown hours 0.6, closing soon 0.5)
//        + 0.20 * social proof  (you saved it +0.4, each friend who saved it +0.35, capped at 1)
//  Places known to be closed right now, more than 25 km away, or a clear
//  mismatch for the vibe (e.g. a cocktail bar for coffee) are dropped, unless
//  that would leave fewer than 3 picks.
//

import Foundation
import CoreLocation

struct TonightRanker {
    static let maxDistanceMeters: Double = 25_000
    static let resultCount = 3

    /// Generic category labels that say nothing about a place's vibe.
    static let genericCategories: Set<String> = [
        "restaurant", "restaurants", "food", "point_of_interest", "point of interest",
        "establishment", "store", "premise", "place", "meal_takeaway", "meal_delivery"
    ]

    let vibe: TonightVibe
    let origin: CLLocation?
    let currentUserId: String
    /// Lowercased friend id -> first name.
    let friendNames: [String: String]
    var usesMetric: Bool = Locale.current.measurementSystem != .us
    var openStatus: (DetailPlace) -> OpenStatus = { OpenStatusService.getStatus(for: $0) }

    /// Returns the top picks for the candidates whose place details are known.
    func rank(candidates: [TonightCandidate], places: [String: DetailPlace], limit: Int = TonightRanker.resultCount) -> [TonightPick] {
        var preferred: [TonightPick] = []
        var fallback: [TonightPick] = []
        for candidate in candidates {
            guard let place = places[candidate.placeId.lowercased()] else { continue }
            let evaluation = evaluate(candidate: candidate, place: place)
            switch evaluation.tier {
            case .preferred: preferred.append(evaluation.pick)
            case .fallback: fallback.append(evaluation.pick)
            case .excluded: continue
            }
        }
        let sortedPreferred = preferred.sorted(by: Self.ordering)
        if sortedPreferred.count >= limit { return Array(sortedPreferred.prefix(limit)) }
        let fill = fallback.sorted(by: Self.ordering).prefix(limit - sortedPreferred.count)
        return sortedPreferred + fill
    }

    // MARK: - Scoring

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
        if hardClosed || vibeFit <= 0 { return (pick, .fallback) }
        return (pick, .preferred)
    }

    /// Returns 0...1 for how well the place's categories fit the vibe (0 = clear mismatch).
    func vibeScore(for place: DetailPlace) -> Double {
        let text = Self.categoryText(for: place)
        let hasStrong = vibe.strongKeywords.contains { text.contains($0) }
        let hasMismatch = vibe.mismatchKeywords.contains { text.contains($0) }
        var score: Double
        if hasStrong {
            score = 1.0
        } else if hasMismatch {
            score = 0
        } else if vibe.weakKeywords.contains(where: { text.contains($0) }) {
            score = 0.55
        } else {
            score = text.isEmpty ? 0.3 : 0.2
        }
        switch vibe {
        case .dinner where place.serversDinner == true: score = max(score, 0.75)
        case .lunch where place.serversLunch == true: score = max(score, 0.75)
        case .coffee where place.servesBreakfast == true: score = max(score, 0.5)
        default: break
        }
        return score
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

    /// Returns lowercased, joined category text used for keyword matching.
    static func categoryText(for place: DetailPlace) -> String {
        var pieces = place.categories ?? []
        if let corrected = place.userCorrectedCategory { pieces.append(corrected) }
        return pieces.map { $0.lowercased().replacingOccurrences(of: "_", with: " ") }.joined(separator: " | ")
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
