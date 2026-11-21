//
//  PlaceVideoInsights.swift
//  loc
//
//  "From videos" place insights: the structured facts the backend extracts from imported videos
//  (TikTok, Instagram, ...) plus the pure aggregation that turns per-video mentions into what the
//  place page shows. Every field is optional so the old backend response shape still decodes.
//

import Foundation

struct PlaceMentionDish: Codable, Hashable {
    let name: String
    let quote: String?
}

/// Per-video structured insights (`place_mentions.insights`). Only facts the creator actually stated.
struct PlaceMentionInsights: Codable, Hashable {
    let dishes: [PlaceMentionDish]?
    let tips: [String]?
    let prices: [String]?
    let wait: String?
    let occasions: [String]?
    let warnings: [String]?
    let quote: String?
}

/// One video's contribution, ready to render as a card.
struct PlaceVideoCard: Identifiable, Hashable {
    let id: String
    let platformLabel: String
    let creator: String?
    let quote: String?
    let highlights: [String]
    let thumbnailURL: String?
    let sourceURL: String?
    let isFromYourImport: Bool
}

/// Aggregated "From videos" content for one place.
struct PlaceVideoInsightsSummary: Equatable {
    var dishChips: [String] = []
    var tips: [String] = []
    var prices: [String] = []
    var warnings: [String] = []
    var occasions: [String] = []
    var cards: [PlaceVideoCard] = []

    static let empty = PlaceVideoInsightsSummary()

    var isEmpty: Bool {
        dishChips.isEmpty && tips.isEmpty && prices.isEmpty && warnings.isEmpty && occasions.isEmpty && cards.isEmpty
    }

    // MARK: Build

    /// - Parameters:
    ///   - mentions: per-video mentions from the backend (any response shape).
    ///   - importedURLs: URLs of the videos the signed-in user imported for this place.
    static func build(mentions: [PlaceMention], importedURLs: [String] = []) -> PlaceVideoInsightsSummary {
        var summary = PlaceVideoInsightsSummary()
        var dishes = Tally(), tips = Tally(), prices = Tally(), warnings = Tally(), occasions = Tally()
        var cards: [PlaceVideoCard] = []

        for mention in mentions {
            let rich = mention.insights
            let dishNames = (rich?.dishes?.map(\.name)).flatMap { $0.isEmpty ? nil : $0 } ?? mention.dishes ?? []
            dishNames.forEach { dishes.add($0) }
            let mentionTips = (rich?.tips).flatMap { $0.isEmpty ? nil : $0 } ?? [mention.tip].compactMap { $0 }
            mentionTips.forEach { tips.add($0) }
            rich?.prices?.forEach { prices.add($0) }
            rich?.warnings?.forEach { warnings.add($0) }
            rich?.occasions?.forEach { occasions.add($0) }

            let quote = clean(rich?.quote) ?? dishQuote(rich)
            var highlights: [String] = []
            highlights.append(contentsOf: dishNames.prefix(3))
            if let tip = mentionTips.first.flatMap { clean($0) } { highlights.append(tip) }
            if let wait = clean(rich?.wait) { highlights.append(wait) }
            if let price = rich?.prices?.first.flatMap { clean($0) } { highlights.append(price) }
            if let warning = rich?.warnings?.first.flatMap(clean) { highlights.append("Heads up: \(warning)") }
            if let vibe = clean(mention.vibe) { highlights.append(vibe) }
            guard quote != nil || !highlights.isEmpty else { continue }

            cards.append(PlaceVideoCard(
                id: mention.videoId,
                platformLabel: platformLabel(for: mention.source),
                creator: handle(mention.author),
                quote: quote,
                highlights: highlights,
                thumbnailURL: mention.thumbnailUrl,
                sourceURL: mention.sourceUrl,
                isFromYourImport: isFromImport(mention, importedURLs: importedURLs)
            ))
        }

        summary.dishChips = dishes.ranked(limit: 12).map { $0.count > 1 ? "\($0.text) ×\($0.count)" : $0.text }
        summary.tips = tips.ranked(limit: 5).map(\.text)
        summary.prices = prices.ranked(limit: 3).map(\.text)
        summary.warnings = warnings.ranked(limit: 3).map(\.text)
        summary.occasions = occasions.ranked(limit: 4).map(\.text)
        // The user's own imports lead; otherwise keep the backend's newest-first order.
        summary.cards = cards.filter(\.isFromYourImport) + cards.filter { !$0.isFromYourImport }
        return summary
    }

    // MARK: Helpers

    /// True when the user's imported URLs contain this mention's video (matched on id, so short
    /// links, query strings and /video vs /photo variants don't matter).
    static func isFromImport(_ mention: PlaceMention, importedURLs: [String]) -> Bool {
        let id = mention.videoId.lowercased()
        guard !id.isEmpty else { return false }
        return importedURLs.contains { url in
            let comps = url.lowercased().split(whereSeparator: { "/?#&=".contains($0) }).map(String.init)
            return comps.contains(id)
        }
    }

    static func platformLabel(for source: String?) -> String {
        switch (source ?? "").lowercased() {
        case "tiktok": return "TikTok"
        case "instagram": return "Instagram"
        case "youtube": return "YouTube"
        case "": return "Video"
        default: return (source ?? "Video").capitalized
        }
    }

    private static func handle(_ author: String?) -> String? {
        guard let a = clean(author?.replacingOccurrences(of: "@", with: "")) else { return nil }
        return "@" + a
    }

    private static func dishQuote(_ rich: PlaceMentionInsights?) -> String? {
        rich?.dishes?.compactMap { clean($0.quote) }.first
    }

    private static func clean(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    /// Case-insensitive frequency counter that keeps first-seen order for ties and the first spelling.
    private struct Tally {
        private var order: [String] = []
        private var text: [String: String] = [:]
        private var counts: [String: Int] = [:]

        mutating func add(_ raw: String) {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            let key = t.lowercased()
            if counts[key] == nil {
                order.append(key)
                text[key] = t
            }
            counts[key, default: 0] += 1
        }

        func ranked(limit: Int) -> [(text: String, count: Int)] {
            let indexed = order.enumerated().map { (index: $0.offset, key: $0.element) }
            let sorted = indexed.sorted {
                let a = counts[$0.key] ?? 0, b = counts[$1.key] ?? 0
                return a != b ? a > b : $0.index < $1.index
            }
            return sorted.prefix(limit).map { (text: text[$0.key] ?? $0.key, count: counts[$0.key] ?? 0) }
        }
    }
}
