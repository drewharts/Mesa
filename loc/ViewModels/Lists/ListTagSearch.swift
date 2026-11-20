//
//  ListTagSearch.swift
//  loc
//
//  Pure engine behind the search field in a list's chip row. Matches a typed query against tag names, their
//  synonyms ("thrift" -> Vintage Clothing) and taxonomy group names ("drinks" -> Bar, Cocktails, Wine Bar), and
//  against each place's name, categories and tags. Case- and diacritic-insensitive; a prefix of any word ranks
//  before a plain substring. Strings are normalized once when the tag index is built. Unit tested in ListTagSearchTests.
//

import Foundation

enum ListTagSearch {
    /// What a query found in a list: the matching tags best first, and the ids (lowercased) of the matching places.
    struct Result: Equatable {
        let tags: [String]
        let placeIds: Set<String>
    }

    /// One place's pre-normalized search text, built once with the tag index so typing never re-normalizes.
    struct PlaceEntry: Equatable {
        let name: String
        let categories: [String]
        let tags: [String]
    }

    /// Rank of a field matched by the whole query; lower is better.
    private enum Tier {
        static let exact = 0
        static let startsWith = 1
        static let wordPrefix = 2
        static let substring = 3
        /// Added to a word-prefix rank when the match came from a synonym instead of the tag's name.
        static let synonymOffset = 10
        /// Added to a word-prefix rank when the match came from the tag's group name.
        static let groupOffset = 20
    }

    /// Normalized forms of one tag's searchable text.
    private struct TagKey {
        let name: String
        let synonyms: [String]
        let group: String
    }

    /// Alternate words people type for a tag. Keys are tag names from PlaceTaxonomy.
    private static let synonymTable: [String: [String]] = [
        "Vintage Clothing": ["vintage", "thrift", "thrifting", "secondhand", "second hand", "used", "resale", "consignment", "preloved"],
        "Coffee": ["cafe", "cafes", "espresso", "latte", "caffeine", "roaster", "roastery"],
        "Bar": ["drinks", "pub", "beer", "tavern", "dive", "lounge"],
        "Cocktails": ["drinks", "cocktail", "speakeasy", "mixology"],
        "Wine Bar": ["drinks", "wine", "vino", "vin", "vins"],
        "Natural Wine": ["wine", "vino", "vin", "vins"],
        "Wine Shop": ["wine", "vino", "vin", "vins", "liquor", "bottle shop"],
        "Winery": ["wine", "vino", "vin", "vins", "vineyard", "distillery"],
        "Brewery": ["beer", "brewpub", "craft beer", "ale", "taproom"],
        "Nightclub": ["club", "dance", "disco"],
        "Ice Cream": ["gelato", "froyo", "frozen yogurt"],
        "Dessert": ["sweets", "pastry", "cake"],
        "Bakery": ["bread", "pastry", "pastries", "croissant"],
        "Tea": ["boba", "bubble tea"],
        "Matcha": ["green tea"],
        "Juice Bar": ["smoothie", "smoothies"],
        "Books": ["bookstore", "bookshop"],
        "Records": ["vinyl", "record store", "lp"],
        "Hotel": ["lodging", "inn", "motel", "hostel"],
        "Vacation Rental": ["airbnb", "rental"],
        "Grocery": ["supermarket", "groceries", "market"],
        "Ramen": ["noodle", "noodles"],
        "Noodles": ["noodle", "ramen"],
        "Fine Dining": ["tasting menu", "michelin"],
        "Brunch": ["breakfast"],
        "Fitness": ["gym", "workout", "yoga"],
        "Spa": ["massage"],
        "Salon": ["hair", "barber", "nails"],
        "Park": ["garden"],
        "Theater": ["theatre", "cinema", "movie"],
        "Music Venue": ["concert", "live music"],
        "Hiking": ["trail", "trails"],
        "Sandwiches": ["sandwich", "deli", "sub"],
        "Burgers": ["burger"],
        "Steak": ["steakhouse"],
        "Seafood": ["fish", "oyster", "oysters"],
        "Mexican": ["taco", "tacos"],
        "Italian": ["pasta"],
        "Korean BBQ": ["kbbq"],
        "Shoes": ["sneakers", "footwear"],
        "Flowers": ["florist"],
        "Antiques": ["antique"],
        "Clothing": ["apparel", "fashion", "boutique"],
        "Electronics": ["tech"],
        "Art Gallery": ["gallery"],
        "Landmark": ["attraction", "sights"]
    ]

    /// Search keys for every taxonomy tag, normalized once.
    private static let tagKeys: [String: TagKey] = {
        var keys: [String: TagKey] = [:]
        for rule in PlaceTaxonomy.rules where keys[rule.tag] == nil {
            keys[rule.tag] = key(forTag: rule.tag, group: rule.group)
        }
        return keys
    }()

    /// Builds the normalized search key for a tag in a group.
    private static func key(forTag tag: String, group: PlaceTagGroup) -> TagKey {
        TagKey(name: normalize(tag), synonyms: (synonymTable[tag] ?? []).map(normalize), group: normalize(group.rawValue))
    }

    /// Lowercased, accent-folded text with punctuation removed and single spaces; empty when nothing searchable remains.
    static func normalize(_ raw: String) -> String {
        PlaceTaxonomy.padded(raw).trimmingCharacters(in: .whitespaces)
    }

    /// The search text of a place: its normalized name, raw categories and the tags it earned.
    static func entry(for place: LightweightPlace, tags: [String]) -> PlaceEntry {
        let categories = ((place.categories ?? []) + [place.user_corrected_category, place.place_type].compactMap { $0 }).map(normalize)
        return PlaceEntry(name: normalize(place.name), categories: categories, tags: tags)
    }

    /// How well a field matches the query (both normalized); nil when it does not match. Lower is better.
    static func rank(query: String, in field: String) -> Int? {
        guard !query.isEmpty, !field.isEmpty else { return nil }
        if field == query { return Tier.exact }
        if field.hasPrefix(query) { return Tier.startsWith }
        if tokensArePrefixes(query: query, of: field) { return Tier.wordPrefix }
        return field.contains(query) ? Tier.substring : nil
    }

    /// Whether every word of the query starts some word of the field ("wine b" matches "natural wine bar").
    private static func tokensArePrefixes(query: String, of field: String) -> Bool {
        let words = field.split(separator: " ")
        return query.split(separator: " ").allSatisfy { token in words.contains { $0.hasPrefix(token) } }
    }

    /// The best rank of a tag for the query across its name, synonyms and group name; nil when none match.
    private static func rank(query: String, forTag tag: String) -> Int? {
        let key = tagKeys[tag] ?? TagKey(name: normalize(tag), synonyms: [], group: "")
        var best = rank(query: query, in: key.name)
        let alternates = key.synonyms.map { ($0, Tier.synonymOffset) } + [(key.group, Tier.groupOffset)]
        for (field, offset) in alternates {
            guard let fieldRank = rank(query: query, in: field), fieldRank <= Tier.wordPrefix else { continue }
            best = min(best ?? Int.max, offset + fieldRank)
        }
        return best
    }

    /// The tags matching the raw query, best match first; equal ranks keep the given order (most common first).
    static func rankedTags(matching rawQuery: String, in tags: [String]) -> [String] {
        let query = normalize(rawQuery)
        guard !query.isEmpty else { return [] }
        let ranked = tags.enumerated().compactMap { offset, tag in rank(query: query, forTag: tag).map { (tag, $0, offset) } }
        return ranked.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.2 < $1.2 }.map(\.0)
    }

    /// Whether a place matches: its name or a category matches the query, or it carries a matching tag.
    private static func matches(_ entry: PlaceEntry, query: String, matchedTags: Set<String>) -> Bool {
        if rank(query: query, in: entry.name) != nil { return true }
        if entry.tags.contains(where: matchedTags.contains) { return true }
        return entry.categories.contains { rank(query: query, in: $0) != nil }
    }

    /// Runs a raw query over a list's tag index; nil for a blank query (meaning "no search").
    static func search(_ rawQuery: String, in index: ListTagIndex) -> Result? {
        let query = normalize(rawQuery)
        guard !query.isEmpty else { return nil }
        let tags = rankedTags(matching: query, in: index.allTags)
        let matchedTags = Set(tags)
        let ids = index.searchEntries.filter { matches($0.value, query: query, matchedTags: matchedTags) }.keys
        return Result(tags: tags, placeIds: Set(ids))
    }
}
