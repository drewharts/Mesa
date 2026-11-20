//
//  ListTypeFilter.swift
//  loc
//
//  Pure engine for the tag chips inside a list (All, Sushi, Japanese, Coffee, Bar, ...), in the style of
//  Spotify's Liked Songs chips: specific tags derived from the places actually in the list. Every raw category
//  (Google snake_case types and human "Sushi restaurant" labels), the user-corrected category and name keywords
//  are mapped to tags by the data table in PlaceTaxonomy; generic and unmapped categories are dropped. A place's
//  primary category decides which family of tags it may carry. Unit tested in ListTypeFilterTests.
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
        let matching = placeIds(tagged: tag)
        return places.filter { matching.contains($0.place_id.lowercased()) }
    }

    /// Ids (lowercased) of every place carrying the tag.
    func placeIds(tagged tag: String) -> Set<String> {
        Set(tagsByPlaceId.filter { $0.value.contains(tag) }.keys.map { $0.lowercased() })
    }

    /// Whether any place carries the tag.
    func contains(tag: String) -> Bool {
        tagsByPlaceId.values.contains { $0.contains(tag) }
    }
}

enum ListTypeFilter {
    /// Fewest qualifying tags a list needs before the chip row is worth showing.
    static let minTagsForChips = 2
    /// Lists with fewer places than this show tags that only one place has.
    static let smallListSize = 10

    /// One raw category after normalization: the tag rules it earns, and how much it says about the place's primary type.
    private struct ClassifiedCategory {
        /// Read from a purely human-readable list ("Sushi restaurant", ...), where Google puts the primary label first
        /// and the rest alphabetically. Lists with snake_case types ("sushi_restaurant") carry no usable order.
        let isOrdered: Bool
        /// A generic "Restaurant"-style label that is not a tag but still marks a dining place when it comes first.
        let isDiningHint: Bool
        /// The plain "restaurant" type, which marks a dining place even in a list without order.
        let isRestaurantType: Bool
        let rules: [PlaceTagRule]
    }

    /// The clean tags for a place, in taxonomy order. The place's primary category picks one family of tags
    /// (dining, shopping, stay, ...) and only tags from that family survive, so a cafe that also lists "Home goods
    /// store" is never a shop. A user-corrected category that maps to a tag replaces the original categories.
    static func tags(of place: LightweightPlace) -> [String] {
        let nameRules = rulesMatching(name: PlaceTaxonomy.padded(place.name))
        let sources = categorySources(of: place)
        let categoryRules = sources.flatMap(\.rules)
        let family = keptFamily(sources: sources, categoryRules: categoryRules, nameRules: nameRules)
        return dropRedundantTags(expandedTags(from: keptRules(in: family, categoryRules: categoryRules, nameRules: nameRules)))
    }

    /// The rules that survive the family choice. With no family, the categories speak for the place and the name
    /// keywords only fill in when the categories earned nothing.
    private static func keptRules(in family: PlaceTagFamily?, categoryRules: [PlaceTagRule], nameRules: [PlaceTagRule]) -> [PlaceTagRule] {
        guard let family = family else { return categoryRules.isEmpty ? nameRules : categoryRules }
        return (categoryRules + nameRules).filter { $0.group.family == family }
    }

    /// The classified categories to read: the user-corrected category when it maps to a tag, else all the place's
    /// categories (and place type), in their original order.
    private static func categorySources(of place: LightweightPlace) -> [ClassifiedCategory] {
        let corrected = classified([place.user_corrected_category].compactMap { $0 }, allOrdered: true)
        if corrected.contains(where: { !$0.rules.isEmpty }) { return corrected }
        return classified((place.categories ?? []) + [place.place_type].compactMap { $0 }, allOrdered: false)
    }

    /// Classifies each raw category; they count as ordered only when every one is a human-readable label.
    private static func classified(_ raw: [String], allOrdered: Bool) -> [ClassifiedCategory] {
        let ordered = allOrdered || raw.allSatisfy(isHumanReadable)
        return raw.compactMap { classify($0, ordered: ordered) }
    }

    /// Whether a raw category is a human-readable label rather than a lowercase snake_case Google type.
    private static func isHumanReadable(_ raw: String) -> Bool {
        raw.contains { !($0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_")) }
    }

    /// The rules one raw category earns; nil when it earns none and is not a dining hint or the restaurant type.
    private static func classify(_ raw: String, ordered: Bool) -> ClassifiedCategory? {
        let key = PlaceTaxonomy.padded(raw).trimmingCharacters(in: .whitespaces)
        let isHint = ordered && PlaceTaxonomy.diningHints.contains(key)
        let isRestaurant = PlaceTaxonomy.restaurantTypes.contains(key)
        let rules = normalizedCategory(raw).map(rulesMatching(category:)) ?? []
        guard !rules.isEmpty || isHint || isRestaurant else { return nil }
        return ClassifiedCategory(isOrdered: ordered, isDiningHint: isHint, isRestaurantType: isRestaurant, rules: rules)
    }

    /// Normalizes a raw category (either format), dropping the word "restaurant"; nil for blank and generic ones.
    private static func normalizedCategory(_ raw: String) -> String? {
        let words = PlaceTaxonomy.padded(raw).split(separator: " ").filter { $0 != "restaurant" && $0 != "restaurants" }
        let text = " " + words.joined(separator: " ") + " "
        return words.isEmpty || PlaceTaxonomy.genericCategories.contains(text.trimmingCharacters(in: .whitespaces)) ? nil : text
    }

    /// The rules earned by one normalized category. A rule can suppress a broader one (Vintage Clothing over
    /// Clothing), and a retail or other non-dining noun wins over a cuisine adjective ("Japanese grocery store").
    private static func rulesMatching(category text: String) -> [PlaceTagRule] {
        var matched = PlaceTaxonomy.rules.filter { rule in
            rule.category.contains { text.contains($0) } || rule.exact.contains(text)
        }
        let suppressed = Set(matched.flatMap(\.suppresses))
        matched.removeAll { suppressed.contains($0.tag) }
        if matched.contains(where: { $0.group.family != .dining }) { matched.removeAll { $0.group == .food } }
        return matched
    }

    /// The rules earned by the (padded) place name through its conservative keywords.
    private static func rulesMatching(name: String) -> [PlaceTagRule] {
        PlaceTaxonomy.rules.filter { rule in
            rule.name.contains { name.contains($0) } || rule.namePrefix.contains { name.contains(" " + $0) }
        }
    }

    /// The one family whose tags a place keeps; nil keeps every family. In an ordered list the first category is the
    /// primary type. Otherwise (no order): lodging wins, then a tag the name confirms, then dining (a dining tag or
    /// the plain "restaurant" type), so a restaurant that also lists "liquor_store" or "grocery_or_supermarket" is no shop.
    private static func keptFamily(sources: [ClassifiedCategory], categoryRules: [PlaceTagRule], nameRules: [PlaceTagRule]) -> PlaceTagFamily? {
        if let primary = sources.first(where: \.isOrdered) {
            if let family = primary.rules.first?.group.family { return family }
            return primary.isDiningHint ? .dining : nil
        }
        var families = Set((categoryRules.isEmpty ? nameRules : categoryRules).map { $0.group.family })
        if sources.contains(where: \.isRestaurantType) { families.insert(.dining) }
        if families.contains(.stay) { return .stay }
        let categoryTags = Set(categoryRules.map(\.tag))
        if let confirmed = nameRules.first(where: { categoryTags.contains($0.tag) }) { return confirmed.group.family }
        return families.contains(.dining) ? .dining : nil
    }

    /// The tags (each followed by the tags it implies) for the kept rules, in taxonomy order without duplicates.
    private static func expandedTags(from kept: [PlaceTagRule]) -> [String] {
        let keptTags = Set(kept.map(\.tag))
        var tags: [String] = []
        for rule in PlaceTaxonomy.rules where keptTags.contains(rule.tag) {
            for tag in [rule.tag] + rule.implies where !tags.contains(tag) { tags.append(tag) }
        }
        return tags
    }

    /// Removes tags made redundant by a more specific one (BBQ under Korean BBQ, Asian under any specific Asian cuisine).
    private static func dropRedundantTags(_ tags: [String]) -> [String] {
        var result = tags.contains("Korean BBQ") ? tags.filter { $0 != "BBQ" } : tags
        if !PlaceTaxonomy.specificAsianTags.isDisjoint(with: result) { result.removeAll { $0 == "Asian" } }
        return result
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

    /// "All" followed by the qualifying tags, most common first (ties alphabetical), all of them. Empty below the minimum.
    private static func chips(from counts: [String: Int], placeCount: Int) -> [ListTypeChip] {
        let threshold = placeCount < smallListSize ? 1 : 2
        let qualifying = counts.filter { $0.value >= threshold }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
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
