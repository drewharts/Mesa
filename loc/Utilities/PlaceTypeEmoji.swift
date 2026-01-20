//
//  PlaceTypeEmoji.swift
//  loc
//
//  Maps place types to representative emojis for map annotations
//

import Foundation

struct PlaceTypeEmoji {
    /// Returns an emoji representing the given place type
    /// Used for map annotations when no user profile photos are available
    static func emoji(for placeType: String) -> String {
        let type = placeType.lowercased()

        // Cuisines
        if type.contains("french") || type.contains("brasserie") {
            return "🥐"
        }
        if type.contains("chinese") || type.contains("cantonese") {
            return "🥡"
        }
        if type.contains("japanese") || type.contains("sushi") || type.contains("ramen") || type.contains("izakaya") {
            return "🍣"
        }
        if type.contains("italian") || type.contains("pizza") {
            return "🍕"
        }
        if type.contains("mexican") || type.contains("taco") || type.contains("burrito") {
            return "🌮"
        }
        if type.contains("indian") {
            return "🍛"
        }
        if type.contains("thai") || type.contains("vietnamese") || type.contains("noodle") {
            return "🍜"
        }
        if type.contains("korean") || type.contains("barbecue") || type.contains("bbq") {
            return "🍖"
        }
        if type.contains("american") || type.contains("hamburger") || type.contains("burger") || type.contains("diner") {
            return "🍔"
        }
        if type.contains("seafood") {
            return "🦞"
        }
        if type.contains("greek") || type.contains("mediterranean") {
            return "🥙"
        }
        if type.contains("steak") {
            return "🥩"
        }
        if type.contains("breakfast") || type.contains("brunch") {
            return "🥞"
        }

        // Drinks
        if type.contains("coffee") || type.contains("espresso") || type.contains("cafe") {
            return "☕"
        }
        if type.contains("cocktail") || type.contains("bar") || type.contains("pub") {
            return "🍸"
        }
        if type.contains("wine") {
            return "🍷"
        }
        if type.contains("tea") {
            return "🍵"
        }
        if type.contains("juice") {
            return "🧃"
        }

        // Other food
        if type.contains("bakery") || type.contains("bagel") {
            return "🥖"
        }
        if type.contains("ice_cream") {
            return "🍦"
        }
        if type.contains("dessert") || type.contains("donut") || type.contains("cookie") {
            return "🍰"
        }
        if type.contains("sandwich") || type.contains("deli") {
            return "🥪"
        }
        if type.contains("salad") || type.contains("health") || type.contains("vegan") || type.contains("vegetarian") {
            return "🥗"
        }
        if type.contains("chicken") {
            return "🍗"
        }

        // Non-food
        if type.contains("museum") || type.contains("gallery") {
            return "🏛️"
        }
        if type.contains("park") {
            return "🌳"
        }
        if type.contains("gym") {
            return "💪"
        }
        if type.contains("spa") {
            return "💆"
        }
        if type.contains("hotel") || type.contains("lodging") {
            return "🏨"
        }

        // Generic restaurant fallback
        if type.contains("restaurant") || type.contains("food") {
            return "🍽️"
        }

        // Default location pin
        return "📍"
    }
}
