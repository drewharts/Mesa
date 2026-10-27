//
//  TonightCategoryClassifier.swift
//  loc
//
//  Sorts a place's categories into the kinds of venue Tonight cares about,
//  then decides per vibe whether the place is eligible and how well it fits.
//  Pure and unit tested. Matching is whole-word ("bar" never matches "barber").
//
//  Vibe rules:
//    Coffee     cafes, coffee shops, espresso bars, tea houses only.
//    Lunch      restaurants, sandwich shops / delis / bagels, bakeries, and cafes
//               that serve food (cafe + serves_lunch or a food/restaurant category).
//               No bar-only or nightlife places; no ice cream / juice / dessert-only.
//    Dinner     restaurants only (a "restaurant" or cuisine-type category). Cafes,
//               bakeries, desserts, juice and tea are out unless the place also has a
//               restaurant category. Breakfast/brunch-only restaurants are out
//               unless they serve dinner.
//    Drinks     bars, wine bars, cocktail bars, pubs, breweries, lounges.
//    Late night bars, nightclubs, and late-night food (pizza, diners, tacos,
//               burgers, ramen, kebabs, fast food).
//

import Foundation

struct TonightCategoryClassifier {
    enum Kind: Hashable {
        case restaurant          // any restaurant / cuisine-type place
        case cuisineRestaurant   // a specific restaurant type ("Japanese restaurant", "Bistro")
        case breakfastRestaurant // breakfast / brunch restaurant
        case lunchFood           // sandwich shop, deli, salad, bagel
        case cafe                // "cafe" (often serves food)
        case coffee              // coffee shop, espresso bar
        case tea                 // tea house
        case bakery              // bakery, pastry shop, patisserie
        case sweets              // dessert, ice cream, gelato, donuts, juice, boba
        case bar                 // bar, pub, brewery, lounge, tavern
        case cocktailOrWineBar   // cocktail bar, wine bar, speakeasy
        case nightlife           // night club, karaoke
        case lateFood            // pizza, diner, taco, burger, ramen, kebab, fast food
    }

    /// Labels with no venue signal on their own.
    static let genericCategories: Set<String> = [
        "food", "point of interest", "establishment", "store", "premise", "place", "building",
        "locality", "political", "route", "sublocality", "neighborhood"
    ]
    /// Categories that are only the plain word "restaurant" (not cuisine-specific).
    static let plainRestaurant: Set<String> = [
        "restaurant", "restaurants", "takeout restaurant", "family restaurant", "meal takeaway", "meal delivery"
    ]
    static let retailWords: Set<String> = ["store", "supermarket", "grocery", "market", "mart", "liquor", "wholesale", "wholesaler", "supplier", "supply", "manufacturer"]

    static let restaurantWords: Set<String> = [
        "restaurant", "restaurants", "steakhouse", "steak house", "bistro", "trattoria", "osteria", "brasserie",
        "diner", "izakaya", "pizzeria", "taqueria", "gastropub", "eatery", "grill", "chophouse", "omakase",
        "sushi", "ramen", "noodle", "noodles", "dim sum", "tapas", "bbq", "barbecue", "seafood", "oyster",
        "kebab", "shawarma", "falafel", "poke", "dumpling", "dumplings", "fast food", "meal takeaway",
        "takeout", "food court", "kitchen", "pizza", "burger", "burgers", "hamburger", "tacos", "taco",
        "fine dining", "cafeteria", "canteen", "brunch", "breakfast", "takeaway", "hawker"
    ]
    static let breakfastWords: Set<String> = ["breakfast", "brunch", "pancake", "pancakes", "waffle", "waffles"]
    static let lunchFoodWords: Set<String> = ["sandwich", "sandwiches", "deli", "delicatessen", "salad", "bagel", "bagels", "hoagie", "lunch"]
    static let cafeWords: Set<String> = ["cafe", "café", "cafes"]
    static let coffeeWords: Set<String> = ["coffee", "espresso", "coffee shop", "coffee roasters", "roastery"]
    static let teaWords: Set<String> = ["tea house", "teahouse", "tea room", "tea"]
    static let bakeryWords: Set<String> = ["bakery", "pastry", "patisserie", "boulangerie", "viennoiserie"]
    static let sweetsWords: Set<String> = ["dessert", "desserts", "ice cream", "gelato", "creamery", "donut", "doughnut",
                                           "juice", "smoothie", "boba", "bubble tea", "frozen yogurt", "cupcake", "chocolate", "candy", "cake", "cookie", "cookies"]
    static let barWords: Set<String> = ["bar", "bars", "pub", "brewery", "brewpub", "taproom", "lounge", "tavern",
                                        "saloon", "beer garden", "beer hall", "winery", "sports bar", "biergarten"]
    static let fancyBarWords: Set<String> = ["cocktail", "cocktails", "wine bar", "speakeasy", "mezcaleria"]
    /// "X bar" phrases that are not bars.
    static let notBarPhrases: Set<String> = ["espresso bar", "juice bar", "salad bar", "coffee bar", "dessert bar",
                                             "tea bar", "sushi bar", "raw bar", "oyster bar", "nail bar", "brow bar",
                                             "blow dry bar", "smoothie bar", "snack bar", "milk bar", "poke bar"]
    static let nightlifeWords: Set<String> = ["night club", "nightclub", "karaoke", "dance club", "jazz club", "disco"]
    static let lateFoodWords: Set<String> = ["pizza", "pizzeria", "diner", "taco", "tacos", "taqueria", "burger", "burgers",
                                             "hamburger", "fast food", "ramen", "kebab", "shawarma", "falafel", "hot dog",
                                             "halal", "late night", "noodle", "noodles", "dumpling", "dumplings"]

    // MARK: - Classification

    /// Kinds for one normalized category (or a name, when `fromName`).
    static func kinds(of rawCategory: String) -> Set<Kind> {
        let text = tokenText(rawCategory)
        if retailWords.contains(where: { matches(text, $0) }) { return [] }
        if matches(text, "bed breakfast") || matches(text, "bed and breakfast") { return [] } // lodging
        var kinds = Set<Kind>()
        let has: (Set<String>) -> Bool = { words in words.contains { matches(text, $0) } }

        let barLike = has(barWords) && !notBarPhrases.contains(where: { matches(text, $0) })
        if has(fancyBarWords) { kinds.insert(.cocktailOrWineBar); kinds.insert(.bar) }
        else if barLike { kinds.insert(.bar) }
        if has(nightlifeWords) { kinds.insert(.nightlife) }

        if has(restaurantWords) || matches(text, "sushi bar") || matches(text, "oyster bar") || matches(text, "raw bar") {
            kinds.insert(.restaurant)
            if has(breakfastWords) { kinds.insert(.breakfastRestaurant) }
            else if has(sweetsWords) { /* "Dessert restaurant" is sweets, not a dinner restaurant */ }
            else if !plainRestaurant.contains(normalized(rawCategory)) { kinds.insert(.cuisineRestaurant) }
        }
        if has(lunchFoodWords) { kinds.insert(.lunchFood) }
        if has(cafeWords) { kinds.insert(.cafe) }
        if has(coffeeWords) { kinds.insert(.coffee) }
        if has(teaWords) && !matches(text, "bubble tea") { kinds.insert(.tea) }
        if has(bakeryWords) { kinds.insert(.bakery) }
        if has(sweetsWords) { kinds.insert(.sweets) }
        if has(lateFoodWords) { kinds.insert(.lateFood) }
        return kinds
    }

    /// Kinds for a place: from its specific categories, or from its name when it only has generic ones.
    static func kinds(for place: DetailPlace) -> Set<Kind> {
        let pieces = categoryPieces(for: place).filter { !genericCategories.contains($0) }
        if pieces.isEmpty { return kinds(of: place.name) }
        let found = pieces.reduce(into: Set<Kind>()) { $0.formUnion(kinds(of: $1)) }
        // A store with a deli/bakery counter (e.g. a gourmet grocery) is still a store.
        let isRetail = pieces.contains { piece in retailWords.contains { matches(tokenText(piece), $0) } }
        let venueKinds: Set<Kind> = [.restaurant, .bar, .cafe, .coffee, .nightlife]
        if isRetail && found.isDisjoint(with: venueKinds) { return [] }
        return found
    }

    // MARK: - Per-vibe fit

    /// Returns 0 when the place is not eligible for the vibe, otherwise 0.6...1.0.
    static func fit(_ place: DetailPlace, vibe: TonightVibe) -> Double {
        let k = kinds(for: place)
        switch vibe {
        case .coffee:
            if k.contains(.coffee) && !k.contains(.cuisineRestaurant) { return 1.0 }
            if k.contains(.cuisineRestaurant) { return 0 } // e.g. an Indian restaurant also tagged "cafe"
            if k.contains(.cafe) { return 0.9 }
            if k.contains(.tea) && !k.contains(.bar) { return 0.8 }
            return 0

        case .lunch:
            // Bar-only / nightlife: out (a bar that is also a restaurant, e.g. bar & grill, is fine).
            let foodKinds: Set<Kind> = [.restaurant, .lunchFood, .bakery, .cafe]
            if k.isDisjoint(with: foodKinds) { return 0 }
            // Dessert-only places (incl. "Dessert restaurant") aren't lunch.
            if k.contains(.sweets) && k.isDisjoint(with: [.cuisineRestaurant, .lunchFood, .breakfastRestaurant, .bakery, .cafe]) { return 0 }
            if k.contains(.lunchFood) { return 1.0 }
            if k.contains(.cuisineRestaurant) || k.contains(.breakfastRestaurant) { return 0.9 }
            if k.contains(.restaurant) { return 0.8 }
            if k.contains(.bakery) { return 0.75 }
            // Cafe only: must serve food.
            if k.contains(.cafe) && place.serversLunch != false {
                let servesFood = place.serversLunch == true || hasFoodSignal(place)
                return servesFood ? 0.7 : 0
            }
            return 0

        case .dinner:
            guard k.contains(.restaurant) else { return 0 }
            let onlyBreakfast = k.contains(.breakfastRestaurant) && !k.contains(.cuisineRestaurant)
                && !categoryPieces(for: place).contains(where: { plainRestaurant.contains($0) })
            if onlyBreakfast && place.serversDinner != true { return 0 }
            // A cafe/bakery that only carries the plain "restaurant" label is still a cafe.
            let cafeish = !k.isDisjoint(with: [.cafe, .coffee, .bakery, .sweets, .tea])
            if cafeish && !k.contains(.cuisineRestaurant) && place.serversDinner != true { return 0 }
            if place.serversDinner == false { return 0 }
            if k.contains(.lunchFood) && place.serversDinner != true { return 0.7 } // sandwich shop / deli that is also a diner
            if k.contains(.cuisineRestaurant) { return 1.0 }
            return 0.85

        case .drinks:
            // Restaurants that also have a bar rank below places that are bars first.
            let restaurantFirst = k.contains(.cuisineRestaurant)
            if k.contains(.cocktailOrWineBar) { return restaurantFirst ? 0.8 : 1.0 }
            if k.contains(.bar) { return restaurantFirst ? 0.7 : 0.9 }
            return 0

        case .lateNight:
            if k.contains(.nightlife) { return 1.0 }
            if k.contains(.bar) { return k.contains(.cuisineRestaurant) && !k.contains(.lateFood) ? 0.75 : 1.0 }
            if k.contains(.lateFood) { return 0.85 }
            return 0
        }
    }

    /// Cafe serves food if Google also tags it as a restaurant / food / sandwich place, or it has a brunch label.
    static func hasFoodSignal(_ place: DetailPlace) -> Bool {
        let pieces = categoryPieces(for: place)
        return pieces.contains { $0 == "food" || $0.contains("restaurant") || $0.contains("brunch") || $0.contains("sandwich") }
    }

    // MARK: - Text helpers

    static func normalized(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)
    }

    static func categoryPieces(for place: DetailPlace) -> [String] {
        var pieces = place.categories ?? []
        if let corrected = place.userCorrectedCategory { pieces.append(corrected) }
        return pieces.map(normalized).filter { !$0.isEmpty }
    }

    /// " word word " form so keywords match whole words only.
    static func tokenText(_ s: String) -> String {
        let words = s.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        return " " + words.joined(separator: " ") + " "
    }

    static func matches(_ tokenText: String, _ keyword: String) -> Bool {
        tokenText.contains(" " + keyword.lowercased() + " ")
    }
}
