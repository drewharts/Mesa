//
//  PlaceTypeTranslator.swift
//  loc
//
//  Translates raw Google Places API category types to human-readable display names
//

import Foundation

struct PlaceTypeTranslator {
    /// Translates a raw place type string to a human-readable format
    /// Example: "american_restaurant" -> "American"
    static func translate(_ rawType: String?) -> String {
        guard let rawType = rawType, !rawType.isEmpty else {
            return "Place"
        }
        
        let normalized = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check exact match first (case-insensitive)
        let lowercased = normalized.lowercased()
        if let translation = translations[lowercased] {
            return translation
        }
        
        // Try to extract cuisine type from patterns like "american_restaurant"
        if let extracted = extractCuisineType(from: normalized) {
            return extracted
        }
        
        // If already nicely formatted (contains spaces and capitals), return as-is
        if isAlreadyFormatted(normalized) {
            return normalized
        }
        
        // Fallback: format the raw type (capitalize, replace underscores)
        return formatRawType(normalized)
    }
    
    // MARK: - Translation Dictionary
    
    /// Dictionary mapping raw Google Places API types to display names
    /// Keys are lowercase for case-insensitive matching
    private static let translations: [String: String] = [
        // Restaurant types (underscore format)
        "american_restaurant": "American",
        "japanese_restaurant": "Japanese",
        "korean_restaurant": "Korean",
        "mexican_restaurant": "Mexican",
        "italian_restaurant": "Italian",
        "chinese_restaurant": "Chinese",
        "thai_restaurant": "Thai",
        "indian_restaurant": "Indian",
        "french_restaurant": "French",
        "spanish_restaurant": "Spanish",
        "greek_restaurant": "Greek",
        "vietnamese_restaurant": "Vietnamese",
        "mediterranean_restaurant": "Mediterranean",
        "seafood_restaurant": "Seafood",
        "steak_house": "Steakhouse",
        "steakhouse": "Steakhouse",
        "pizza_restaurant": "Pizza",
        "pizza": "Pizza",
        "burger_restaurant": "Burger",
        "bbq_restaurant": "BBQ",
        "barbecue_restaurant": "BBQ",
        "sushi_restaurant": "Sushi",
        "sushi": "Sushi",
        "asian_restaurant": "Asian",
        "asian_fusion_restaurant": "Asian Fusion",
        "caribbean_restaurant": "Caribbean",
        "cuban_restaurant": "Cuban",
        "brunch_restaurant": "Brunch",
        "breakfast_restaurant": "Breakfast",
        
        // Food & dining (underscore format)
        "bar": "Bar",
        "bar_and_grill": "Bar & Grill",
        "cafe": "Cafe",
        "coffee_shop": "Coffee Shop",
        "bakery": "Bakery",
        "restaurant": "Restaurant",
        "fast_food": "Fast Food",
        "food": "Food",
        "deli": "Deli",
        "ice_cream_shop": "Ice Cream",
        "dessert": "Dessert",
        
        // Retail & stores
        "clothing_store": "Clothing Store",
        "book_store": "Book Store",
        "bookstore": "Book Store",
        "convenience_store": "Convenience Store",
        "grocery_store": "Grocery Store",
        "department_store": "Department Store",
        "beauty_salon": "Beauty Salon",
        "bicycle_store": "Bicycle Store",
        "car_repair": "Auto Repair",
        
        // Services & infrastructure
        "bank": "Bank",
        "atm": "ATM",
        "bus_station": "Bus Station",
        "train_station": "Train Station",
        "airport": "Airport",
        "gas_station": "Gas Station",
        "parking": "Parking",
        "hospital": "Hospital",
        "doctor": "Doctor",
        "dentist": "Dentist",
        "pharmacy": "Pharmacy",
        "veterinary_care": "Veterinary",
        "vet": "Veterinary",
        
        // Entertainment & recreation
        "movie_theater": "Movie Theater",
        "cinema": "Cinema",
        "art_gallery": "Art Gallery",
        "museum": "Museum",
        "zoo": "Zoo",
        "aquarium": "Aquarium",
        "park": "Park",
        "beach": "Beach",
        "gym": "Gym",
        "fitness_center": "Fitness Center",
        "bowling_alley": "Bowling Alley",
        "golf_course": "Golf Course",
        "campground": "Campground",
        
        // Religious & cultural
        "church": "Church",
        "temple": "Temple",
        "mosque": "Mosque",
        "synagogue": "Synagogue",
        "cemetery": "Cemetery",
        
        // Accommodation
        "hotel": "Hotel",
        "motel": "Motel",
        "lodging": "Lodging",
        
        // Business & professional
        "lawyer": "Law Office",
        "real_estate_agency": "Real Estate",
        "insurance_agency": "Insurance",
        "accounting": "Accounting",
        "convention_center": "Convention Center",
    ]
    
    // MARK: - Helper Methods
    
    /// Extracts cuisine type from compound names like "american_restaurant"
    private static func extractCuisineType(from rawType: String) -> String? {
        let lowercased = rawType.lowercased()
        
        // Pattern: {cuisine}_restaurant -> {Cuisine}
        if lowercased.hasSuffix("_restaurant") {
            let cuisine = String(lowercased.dropLast("_restaurant".count))
            if !cuisine.isEmpty {
                return capitalizeWords(cuisine.replacingOccurrences(of: "_", with: " "))
            }
        }
        
        // Pattern: {cuisine}_food -> {Cuisine}
        if lowercased.hasSuffix("_food") {
            let cuisine = String(lowercased.dropLast("_food".count))
            if !cuisine.isEmpty {
                return capitalizeWords(cuisine.replacingOccurrences(of: "_", with: " "))
            }
        }
        
        return nil
    }
    
    /// Checks if a string is already nicely formatted (has spaces and capitals)
    private static func isAlreadyFormatted(_ string: String) -> Bool {
        // If it contains spaces and has capital letters, likely already formatted
        return string.contains(" ") && string.range(of: "[A-Z]", options: .regularExpression) != nil
    }
    
    /// Formats a raw type string (capitalize, replace underscores)
    private static func formatRawType(_ rawType: String) -> String {
        // Replace underscores with spaces and capitalize
        let withSpaces = rawType.replacingOccurrences(of: "_", with: " ")
        return capitalizeWords(withSpaces)
    }
    
    /// Capitalizes words in a string (handles multiple words)
    private static func capitalizeWords(_ string: String) -> String {
        return string
            .split(separator: " ")
            .map { word in
                let lowercased = word.lowercased()
                // Handle special cases like "&" and abbreviations
                if lowercased == "&" {
                    return "&"
                }
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }
}
