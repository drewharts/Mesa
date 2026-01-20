//
//  KeywordMappingService.swift
//  loc
//
//  Maps user search keywords to relevant place types
//

import Foundation

class KeywordMappingService {
    static let shared = KeywordMappingService()

    private init() {}

    // MARK: - Keyword to Place Types Mapping

    /// Maps search keywords to database category values (Google format: lowercase_with_underscores)
    /// IMPORTANT: Only use categories that exist in the Supabase places.categories column
    /// DO NOT include generic categories like "restaurant", "food", "establishment"
    private let keywordMappings: [String: [String]] = [
        // Cuisines (Google format only)
        "chinese": ["chinese_restaurant", "cantonese_restaurant", "chinese_noodle_restaurant"],
        "japanese": ["japanese_restaurant", "izakaya_restaurant", "japanese_curry_restaurant"],
        "sushi": ["sushi_restaurant", "sushi_takeaway"],
        "mexican": ["mexican_restaurant", "taco_restaurant", "mexican_torta_restaurant", "burrito_restaurant"],
        "italian": ["italian_restaurant"],
        "pizza": ["pizza_restaurant"],
        "korean": ["korean_restaurant", "korean_barbecue_restaurant"],
        "american": ["american_restaurant", "hamburger_restaurant", "diner"],
        "thai": ["thai_restaurant"],
        "vietnamese": ["vietnamese_restaurant"],
        "french": ["french_restaurant", "modern_french_restaurant", "brasserie"],
        "indian": ["indian_restaurant"],
        "seafood": ["seafood_restaurant"],
        "mediterranean": ["mediterranean_restaurant"],
        "middle eastern": ["middle_eastern_restaurant", "lebanese_restaurant", "israeli_restaurant"],
        "greek": ["greek_restaurant"],
        "spanish": ["spanish_restaurant"],
        "caribbean": ["caribbean_restaurant", "cuban_restaurant", "dominican_restaurant", "puerto_rican_restaurant"],
        "asian": ["asian_restaurant", "asian_fusion_restaurant"],
        "european": ["european_restaurant", "eastern_european_restaurant"],
        "peruvian": ["peruvian_restaurant"],
        "brazilian": ["brazilian_restaurant"],
        "irish": ["irish_pub", "irish_restaurant"],
        "taiwanese": ["taiwanese_restaurant"],
        "latin": ["latin_american_restaurant"],

        // Food types
        "ramen": ["ramen_restaurant"],
        "noodles": ["ramen_restaurant", "chinese_noodle_restaurant"],
        "pho": ["vietnamese_restaurant"],
        "dim sum": ["chinese_restaurant", "cantonese_restaurant"],
        "dumplings": ["chinese_restaurant", "cantonese_restaurant"],
        "brunch": ["brunch_restaurant", "breakfast_restaurant"],
        "breakfast": ["brunch_restaurant", "breakfast_restaurant"],
        "bbq": ["barbecue_restaurant", "korean_barbecue_restaurant"],
        "barbecue": ["barbecue_restaurant", "korean_barbecue_restaurant"],
        "steak": ["steak_house"],
        "fine dining": ["fine_dining_restaurant"],
        "fast food": ["fast_food_restaurant"],
        "burger": ["hamburger_restaurant", "american_restaurant"],
        "hamburger": ["hamburger_restaurant", "american_restaurant"],
        "cheeseburger": ["hamburger_restaurant", "american_restaurant"],
        "tacos": ["taco_restaurant", "mexican_restaurant"],
        "taco": ["taco_restaurant", "mexican_restaurant"],
        "burrito": ["burrito_restaurant", "mexican_restaurant"],
        "burritos": ["burrito_restaurant", "mexican_restaurant"],

        // Dietary
        "vegetarian": ["vegetarian_restaurant", "vegan_restaurant", "health_food_restaurant"],
        "vegan": ["vegan_restaurant", "vegetarian_restaurant"],
        "gluten free": ["gluten_free_restaurant"],
        "halal": ["halal_restaurant"],
        "salad": ["salad_shop"],

        // Drinks & Coffee
        "coffee": ["coffee_shop", "espresso_bar", "coffee_roasters"],
        "espresso": ["espresso_bar", "coffee_shop"],
        "bakery": ["bakery", "bagel_shop", "donut_shop", "cookie_shop"],
        "donuts": ["donut_shop", "bakery"],
        "donut": ["donut_shop", "bakery"],
        "bagel": ["bagel_shop", "bakery"],
        "wine": ["wine_bar"],
        "cocktails": ["cocktail_bar"],
        "cocktail": ["cocktail_bar"],
        "bar": ["wine_bar", "cocktail_bar", "irish_pub"],

        // Desserts
        "ice cream": ["ice_cream_shop"],
        "dessert": ["dessert_shop", "dessert_restaurant"],

        // Other food
        "sandwich": ["sandwich_shop", "deli"],
        "sandwiches": ["sandwich_shop", "deli"],
        "deli": ["deli", "sandwich_shop"],
        "soup": ["soup_restaurant"],
        "chicken": ["chicken_restaurant"],
        "juice": ["juice_shop"],
        "tea": ["tea_house"],
        "bistro": ["bistro"],

        // Non-food
        "museum": ["museum", "art_museum", "art_gallery"],
        "park": ["park"],
        "gym": ["gym"],
        "spa": ["spa"],
        "hotel": ["lodging", "hotel"],
    ]

    // MARK: - Public Methods

    /// Returns place types for an exact keyword match
    func getPlaceTypes(for keyword: String) -> [String]? {
        return keywordMappings[keyword.lowercased()]
    }

    /// Finds matching keywords within a search query
    /// Returns all matches sorted by keyword length (longest first for more specific matches)
    func findMatchingKeywords(in query: String) -> [(keyword: String, types: [String])] {
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)

        var matches: [(keyword: String, types: [String])] = []

        for (keyword, types) in keywordMappings {
            // Check if the query contains this keyword
            if lowercasedQuery.contains(keyword) || keyword.contains(lowercasedQuery) {
                matches.append((keyword: keyword, types: types))
            }
        }

        // Sort by keyword length descending (prefer more specific matches)
        matches.sort { $0.keyword.count > $1.keyword.count }

        return matches
    }

    /// Returns all unique place types for multiple keywords
    func getPlaceTypesForKeywords(_ keywords: [String]) -> [String] {
        var allTypes = Set<String>()

        for keyword in keywords {
            if let types = getPlaceTypes(for: keyword) {
                allTypes.formUnion(types)
            }
        }

        return Array(allTypes)
    }
}
