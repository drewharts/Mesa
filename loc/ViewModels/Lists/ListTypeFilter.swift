//
//  ListTypeFilter.swift
//  loc
//
//  Pure rules for the tag chips inside a list (All, Sushi, Japanese, Coffee, Bar, ...), in the style of
//  Spotify's Liked Songs chips: specific tags derived from the places actually in the list. Every raw category
//  (Google snake_case types and human "Sushi restaurant" labels), the user-corrected category and name keywords
//  are mapped to clean tags; generic and unmapped categories are dropped. Unit tested in ListTypeFilterTests.
//

import Foundation

/// One chip in a list's horizontally scrolling filter row. `tag == nil` is "All".
struct ListTypeChip: Hashable, Identifiable {
    let tag: String?
    let title: String

    var id: String { tag ?? "all" }
}

/// Tags computed once for a set of places: the chip row plus each place's tags for cheap filtering.
struct ListTagIndex {
    let chips: [ListTypeChip]
    let tagsByPlaceId: [String: [String]]

    static let empty = ListTagIndex(chips: [], tagsByPlaceId: [:])

    /// The places carrying a tag; nil ("All") keeps everything.
    func places(tagged tag: String?, in places: [LightweightPlace]) -> [LightweightPlace] {
        guard let tag else { return places }
        return places.filter { tagsByPlaceId[$0.place_id]?.contains(tag) ?? false }
    }

    /// Whether any place carries the tag.
    func contains(tag: String) -> Bool {
        tagsByPlaceId.values.contains { $0.contains(tag) }
    }
}

enum ListTypeFilter {
    /// Fewest qualifying tags a list needs before the chip row is worth showing.
    static let minTagsForChips = 2
    /// Most tag chips shown (not counting "All").
    static let maxTagChips = 15
    /// Lists with fewer places than this show tags that only one place has.
    static let smallListSize = 10

    /// One tag and the phrases that earn it: from a normalized category (contained as whole words, or
    /// matching the whole category for `exact`) and (for safe words) the place's name.
    private struct Rule {
        let tag: String
        let category: [String]
        let exact: [String]
        let name: [String]
        let implies: [String]

        init(_ tag: String, category: [String], exact: [String] = [], name: [String] = [], implies: [String] = []) {
            self.tag = tag
            self.category = category.map(ListTypeFilter.padded)
            self.exact = exact.map(ListTypeFilter.padded)
            self.name = name.map(ListTypeFilter.padded)
            self.implies = implies
        }
    }

    /// Categories that say nothing about what a place is; ignored (compared after normalization).
    private static let genericCategories: Set<String> = [
        "establishment", "point of interest", "food", "restaurant", "store", "meal takeaway", "meal delivery",
        "lounge", "event venue", "place"
    ]

    /// Rules in display-priority order. A phrase matches whole words only.
    private static let rules: [Rule] = [
        Rule("Sushi", category: ["sushi"], name: ["sushi"], implies: ["Japanese"]),
        Rule("Omakase", category: ["omakase"], name: ["omakase"], implies: ["Japanese"]),
        Rule("Ramen", category: ["ramen"], name: ["ramen"], implies: ["Japanese"]),
        Rule("Japanese", category: ["japanese", "izakaya", "yakitori", "tempura", "udon"], name: ["japanese", "izakaya", "yakitori"]),
        Rule("Korean BBQ", category: ["korean barbecue", "korean bbq"], name: ["kbbq", "korean bbq"], implies: ["Korean"]),
        Rule("Korean", category: ["korean"], name: ["korean"]),
        Rule("Thai", category: ["thai"], name: ["thai"]),
        Rule("Vietnamese", category: ["vietnamese", "pho"], name: ["vietnamese", "pho"]),
        Rule("Chinese", category: ["chinese", "dim sum", "dumpling", "szechuan", "sichuan", "cantonese"], name: ["dim sum", "dumpling", "dumplings"]),
        Rule("Mexican", category: ["mexican", "taco", "tacos", "taqueria"], name: ["taqueria", "taco", "tacos", "burrito"]),
        Rule("Italian", category: ["italian", "trattoria", "osteria"], name: ["trattoria", "osteria", "italian"]),
        Rule("Pizza", category: ["pizza", "pizzeria"], name: ["pizza", "pizzeria"]),
        Rule("French", category: ["french", "bistro", "brasserie"], name: ["bistro", "brasserie"]),
        Rule("Indian", category: ["indian"], name: ["indian"]),
        Rule("Israeli", category: ["israeli"], name: ["israeli"]),
        Rule("Middle Eastern", category: ["middle eastern", "lebanese", "turkish", "falafel", "kebab", "shawarma"], name: ["falafel", "kebab", "shawarma"]),
        Rule("Mediterranean", category: ["mediterranean"], name: ["mediterranean"]),
        Rule("American", category: [], exact: ["american", "new american", "traditional american", "modern american", "contemporary american"]),
        Rule("Greek", category: ["greek"], name: ["greek"]),
        Rule("Spanish", category: ["spanish", "tapas"], name: ["tapas"]),
        Rule("Steak", category: ["steak house", "steakhouse", "steak"], name: ["steakhouse", "steak house"]),
        Rule("Seafood", category: ["seafood"], name: ["seafood", "oyster", "oysters"]),
        Rule("BBQ", category: ["barbecue", "bbq"], name: ["barbecue", "bbq"]),
        Rule("Burgers", category: ["burger", "burgers", "hamburger"], name: ["burger", "burgers"]),
        Rule("Sandwiches", category: ["sandwich", "sandwiches", "deli", "delicatessen"], name: ["sandwich", "sandwiches", "deli"]),
        Rule("Vegan", category: ["vegan", "vegetarian"], name: ["vegan"]),
        Rule("Bakery", category: ["bakery", "patisserie", "bagel", "bagels"], name: ["bakery", "patisserie", "boulangerie", "bagel", "bagels"]),
        Rule("Dessert", category: ["dessert", "candy", "chocolate", "confectionery"], name: ["dessert", "desserts"]),
        Rule("Ice Cream", category: ["ice cream", "gelato", "frozen yogurt"], name: ["ice cream", "gelato", "creamery"]),
        Rule("Coffee", category: ["coffee", "cafe", "espresso"], name: ["coffee", "espresso", "roasters", "roastery", "cafe"]),
        Rule("Matcha", category: ["matcha"], name: ["matcha"]),
        Rule("Tea", category: ["tea house", "tea store", "tea room", "bubble tea"], name: ["tea house", "teahouse"]),
        Rule("Brunch", category: ["brunch", "breakfast"], name: ["brunch"]),
        Rule("Wine Bar", category: ["wine bar"], name: ["wine bar", "wine", "vino"]),
        Rule("Cocktails", category: ["cocktail", "cocktails", "speakeasy"], name: ["cocktail", "cocktails", "speakeasy"]),
        Rule("Brewery", category: ["brewery", "brewpub", "beer"], name: ["brewery", "brewing", "brewpub"]),
        Rule("Bar", category: [], exact: ["bar", "bars", "pub", "gastropub", "irish pub", "sports bar", "night club", "nightclub", "dive bar"], name: ["pub"]),
        Rule("Grocery", category: ["grocery", "supermarket", "convenience store", "farmers market", "market"], name: ["grocery", "supermarket"]),
        Rule("Vintage", category: ["vintage", "thrift", "consignment", "second hand", "antique"], name: ["vintage", "thrift", "consignment"]),
        Rule("Shopping", category: ["clothing store", "book store", "bookstore", "boutique", "shopping mall", "department store",
                                   "gift shop", "jewelry store", "shoe store", "furniture store", "home goods store", "record store"]),
        Rule("Museum", category: ["museum", "art gallery", "gallery"], name: ["museum"]),
        Rule("Park", category: ["park", "garden", "botanical garden", "national park"]),
        Rule("Hotel", category: ["hotel", "lodging", "resort", "hostel", "motel", "inn"], name: ["hotel"])
    ]

    /// Lowercased, accent-folded text with punctuation removed, wrapped in spaces so whole words match.
    private static func padded(_ text: String) -> String {
        let folded = text.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        let spaced = String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return " " + spaced.split(separator: " ").joined(separator: " ") + " "
    }

    /// The clean tags for a place, in rule order, from all its categories and its name. A user-corrected
    /// category that maps to a tag replaces the original categories. Generic/unmapped categories yield none.
    static func tags(of place: LightweightPlace) -> [String] {
        let name = padded(place.name)
        let corrected = normalizedCategories([place.user_corrected_category].compactMap { $0 })
        let correctedMapsToTag = !matchedRules(for: corrected, name: "").isEmpty
        let sources = correctedMapsToTag ? corrected : normalizedCategories((place.categories ?? []) + [place.place_type].compactMap { $0 })
        var tags: [String] = []
        for rule in matchedRules(for: sources, name: name) {
            for tag in [rule.tag] + rule.implies where !tags.contains(tag) { tags.append(tag) }
        }
        return dropRedundantTags(tags)
    }

    /// Normalizes raw categories (either format) and drops blank and generic ones.
    private static func normalizedCategories(_ raw: [String]) -> [String] {
        raw.compactMap { category -> String? in
            let words = padded(category).split(separator: " ").filter { $0 != "restaurant" && $0 != "restaurants" }
            let text = " " + words.joined(separator: " ") + " "
            return words.isEmpty || genericCategories.contains(text.trimmingCharacters(in: .whitespaces)) ? nil : text
        }
    }

    /// The rules earned by any of the normalized categories or by the (padded) name.
    private static func matchedRules(for categories: [String], name: String) -> [Rule] {
        rules.filter { rule in
            categories.contains { text in
                rule.category.contains { text.contains($0) } || rule.exact.contains(text)
            } || rule.name.contains { name.contains($0) }
        }
    }

    /// Removes tags made redundant by a more specific one (plain BBQ under Korean BBQ).
    private static func dropRedundantTags(_ tags: [String]) -> [String] {
        tags.contains("Korean BBQ") ? tags.filter { $0 != "BBQ" } : tags
    }

    /// Computes every place's tags and the chip row once. Chips are empty when the list has too few tags to filter.
    static func index(for places: [LightweightPlace]) -> ListTagIndex {
        var tagsByPlaceId: [String: [String]] = [:]
        var counts: [String: Int] = [:]
        for place in places {
            let tags = tags(of: place)
            tagsByPlaceId[place.place_id] = tags
            for tag in tags { counts[tag, default: 0] += 1 }
        }
        return ListTagIndex(chips: chips(from: counts, placeCount: places.count), tagsByPlaceId: tagsByPlaceId)
    }

    /// "All" followed by the qualifying tags, most common first (ties alphabetical), capped. Empty below the minimum.
    private static func chips(from counts: [String: Int], placeCount: Int) -> [ListTypeChip] {
        let threshold = placeCount < smallListSize ? 1 : 2
        let qualifying = counts.filter { $0.value >= threshold }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(maxTagChips)
        guard qualifying.count >= minTagsForChips else { return [] }
        return [ListTypeChip(tag: nil, title: "All")] + qualifying.map { ListTypeChip(tag: $0.key, title: $0.key) }
    }

    /// The chip row for a list of places.
    static func chips(for places: [LightweightPlace]) -> [ListTypeChip] {
        index(for: places).chips
    }

    /// One entry per place: duplicate ids (same place reached twice, sometimes with different id casing)
    /// would give a lazy grid duplicate identities, so only the first occurrence is kept.
    static func uniquePlaces(_ places: [LightweightPlace]) -> [LightweightPlace] {
        var seen = Set<String>()
        return places.filter { seen.insert($0.place_id.lowercased()).inserted }
    }

    /// The places a selection keeps; nil ("All") keeps everything.
    static func apply(_ selection: String?, to places: [LightweightPlace]) -> [LightweightPlace] {
        guard let selection else { return places }
        return places.filter { tags(of: $0).contains(selection) }
    }
}
