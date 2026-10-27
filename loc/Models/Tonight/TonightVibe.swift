//
//  TonightVibe.swift
//  loc
//
//  The kind of outing Tonight ranks for. Inferred from the time of day so
//  Tonight can show picks instantly with zero input; the user may override it.
//

import Foundation

enum TonightVibe: String, CaseIterable, Identifiable, Codable {
    case coffee
    case lunch
    case dinner
    case drinks
    case lateNight

    var id: String { rawValue }

    /// Short chip label.
    var label: String {
        switch self {
        case .coffee: return "Coffee"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .drinks: return "Drinks"
        case .lateNight: return "Late night"
        }
    }

    /// SF Symbol shown on the chip.
    var symbol: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .lunch: return "takeoutbag.and.cup.and.straw.fill"
        case .dinner: return "fork.knife"
        case .drinks: return "wineglass.fill"
        case .lateNight: return "moon.stars.fill"
        }
    }

    /// Title for the Tonight sheet header ("Coffee near you").
    var headline: String {
        switch self {
        case .coffee: return "Coffee right now"
        case .lunch: return "Lunch spots"
        case .dinner: return "Dinner tonight"
        case .drinks: return "Drinks tonight"
        case .lateNight: return "Late night"
        }
    }

    /// Returns the vibe that best fits the given local hour (0-23).
    static func inferred(forHour hour: Int) -> TonightVibe {
        switch hour {
        case 5..<11: return .coffee
        case 11..<15: return .lunch
        case 15..<17: return .coffee
        case 17..<21: return .dinner
        case 21..<24: return .drinks
        default: return .lateNight
        }
    }

    /// Returns the vibe for the current moment in the user's calendar/time zone.
    static func inferred(now: Date = Date(), calendar: Calendar = .current) -> TonightVibe {
        inferred(forHour: calendar.component(.hour, from: now))
    }

    /// Strong category keywords (lowercased substrings) for this vibe.
    var strongKeywords: [String] {
        switch self {
        case .coffee: return ["coffee", "cafe", "café", "espresso", "tea house", "bakery"]
        case .lunch: return ["sandwich", "deli", "lunch", "salad", "taco", "burrito", "noodle", "ramen", "pho", "pizza", "bagel", "fast casual"]
        case .dinner: return ["restaurant", "steak", "sushi", "italian", "bistro", "trattoria", "omakase", "brasserie", "tasting"]
        case .drinks: return ["bar", "cocktail", "wine", "pub", "brewery", "beer", "speakeasy", "lounge", "tavern"]
        case .lateNight: return ["bar", "club", "pizza", "diner", "taco", "late", "karaoke", "lounge", "night"]
        }
    }

    /// Weaker, adjacent keywords that still fit this vibe.
    var weakKeywords: [String] {
        switch self {
        case .coffee: return ["brunch", "breakfast", "dessert", "patisserie", "juice"]
        case .lunch: return ["restaurant", "cafe", "bakery", "brunch", "food"]
        case .dinner: return ["bar", "wine", "pizza", "ramen", "taco", "food"]
        case .drinks: return ["restaurant", "bistro", "club", "rooftop"]
        case .lateNight: return ["restaurant", "burger", "ramen", "food"]
        }
    }

    /// Keywords that make a place a poor fit for this vibe.
    var mismatchKeywords: [String] {
        switch self {
        case .coffee: return ["bar", "pub", "club", "steak", "cocktail"]
        case .lunch: return ["club", "cocktail", "speakeasy"]
        case .dinner: return ["coffee shop", "espresso", "juice"]
        case .drinks: return ["coffee", "cafe", "bakery", "juice", "breakfast"]
        case .lateNight: return ["coffee", "cafe", "bakery", "breakfast", "brunch"]
        }
    }
}
