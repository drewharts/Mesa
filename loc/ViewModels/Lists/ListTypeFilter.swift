//
//  ListTypeFilter.swift
//  loc
//
//  Pure rules for the tag chips inside a list (All, Sushi, Japanese, Coffee, Bar, ...), in the style of
//  Spotify's Liked Songs chips: specific tags derived from the places actually in the list. Raw categories
//  and name keywords are mapped to clean tags; unmapped categories are dropped. Unit tested in ListTypeFilterTests.
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

    /// One tag and the phrases that earn it: from the place's category and (for safe words) its name.
    private struct Rule {
        let tag: String
        let category: [String]
        let name: [String]
        let implies: [String]

        init(_ tag: String, category: [String], name: [String] = [], implies: [String] = []) {
            self.tag = tag
            self.category = category.map(ListTypeFilter.padded)
            self.name = name.map(ListTypeFilter.padded)
            self.implies = implies
        }
    }

    /// Rules in display-priority order. A phrase matches whole words only.
    private static let rules: [Rule] = [
        Rule("Sushi", category: ["sushi"], name: ["sushi"], implies: ["Japanese"]),
        Rule("Omakase", category: ["omakase"], name: ["omakase"], implies: ["Japanese"]),
        Rule("Ramen", category: ["ramen"], name: ["ramen"], implies: ["Japanese"]),
        Rule("Japanese", category: ["japanese", "izakaya", "yakitori", "tempura", "udon"], name: ["japanese", "izakaya", "yakitori"]),
        Rule("Korean", category: ["korean", "korean bbq"], name: ["korean", "kbbq"]),
        Rule("Thai", category: ["thai"], name: ["thai"]),
        Rule("Vietnamese", category: ["vietnamese", "pho"], name: ["vietnamese", "pho"]),
        Rule("Chinese", category: ["chinese", "dim sum", "dumpling", "szechuan", "sichuan", "cantonese"], name: ["dim sum", "dumpling", "dumplings"]),
        Rule("Mexican", category: ["mexican", "taco", "tacos", "taqueria"], name: ["taqueria", "taco", "tacos", "burrito"]),
        Rule("Italian", category: ["italian", "trattoria", "osteria"], name: ["trattoria", "osteria", "italian"]),
        Rule("Pizza", category: ["pizza", "pizzeria"], name: ["pizza", "pizzeria"]),
        Rule("French", category: ["french", "bistro", "brasserie"], name: ["bistro", "brasserie"]),
        Rule("Indian", category: ["indian"], name: ["indian"]),
        Rule("Middle Eastern", category: ["middle eastern", "lebanese", "turkish", "israeli", "falafel", "kebab", "shawarma"], name: ["falafel", "kebab", "shawarma"]),
        Rule("Mediterranean", category: ["mediterranean"], name: ["mediterranean"]),
        Rule("Greek", category: ["greek"], name: ["greek"]),
        Rule("Spanish", category: ["spanish", "tapas"], name: ["tapas"]),
        Rule("Steakhouse", category: ["steak house", "steakhouse"], name: ["steakhouse", "steak house"]),
        Rule("Seafood", category: ["seafood"], name: ["seafood", "oyster", "oysters"]),
        Rule("Barbecue", category: ["barbecue", "bbq"], name: ["barbecue", "bbq"]),
        Rule("Burgers", category: ["burger", "burgers", "hamburger"], name: ["burger", "burgers"]),
        Rule("Sandwiches", category: ["sandwich", "sandwiches", "deli", "delicatessen"], name: ["sandwich", "sandwiches", "deli"]),
        Rule("Vegan", category: ["vegan", "vegetarian"], name: ["vegan"]),
        Rule("Bakery", category: ["bakery", "patisserie", "bagel", "bagels"], name: ["bakery", "patisserie", "boulangerie", "bagel", "bagels"]),
        Rule("Dessert", category: ["dessert", "candy", "chocolate", "confectionery"], name: ["dessert", "desserts"]),
        Rule("Ice Cream", category: ["ice cream", "gelato", "frozen yogurt"], name: ["ice cream", "gelato", "creamery"]),
        Rule("Coffee", category: ["coffee", "cafe", "espresso"], name: ["coffee", "espresso", "roasters", "roastery", "cafe"]),
        Rule("Matcha", category: ["matcha"], name: ["matcha"]),
        Rule("Tea", category: ["tea house", "tea store", "tea room", "bubble tea"], name: ["tea house", "teahouse"]),
        Rule("Brunch", category: ["brunch", "breakfast restaurant"], name: ["brunch"]),
        Rule("Wine Bar", category: ["wine bar"], name: ["wine bar", "vino"]),
        Rule("Cocktails", category: ["cocktail", "cocktails", "speakeasy"], name: ["cocktail", "cocktails", "speakeasy"]),
        Rule("Brewery", category: ["brewery", "brewpub", "beer"], name: ["brewery", "brewing", "brewpub"]),
        Rule("Bar", category: ["bar", "pub", "lounge", "night club", "nightclub"], name: ["pub"]),
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

    /// The clean tags for a place, in rule order, from its category and name. Unmapped categories yield none.
    static func tags(of place: LightweightPlace) -> [String] {
        let category = padded(place.place_type ?? "")
        let name = padded(place.name)
        var tags: [String] = []
        for rule in rules {
            let matches = rule.category.contains { category.contains($0) } || rule.name.contains { name.contains($0) }
            guard matches else { continue }
            for tag in [rule.tag] + rule.implies where !tags.contains(tag) { tags.append(tag) }
        }
        return dropRedundantBar(tags)
    }

    /// Removes the generic "Bar" tag when a more specific bar tag is present.
    private static func dropRedundantBar(_ tags: [String]) -> [String] {
        let specific: Set<String> = ["Wine Bar", "Cocktails", "Brewery"]
        return tags.contains(where: specific.contains) ? tags.filter { $0 != "Bar" } : tags
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

    /// The places a selection keeps; nil ("All") keeps everything.
    static func apply(_ selection: String?, to places: [LightweightPlace]) -> [LightweightPlace] {
        guard let selection else { return places }
        return places.filter { tags(of: $0).contains(selection) }
    }
}
