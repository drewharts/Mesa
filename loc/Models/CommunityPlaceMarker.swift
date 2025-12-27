//
//  CommunityPlaceMarker.swift
//  loc
//
//  Represents a place saved by users outside the current user's network
//  Displayed as small emoji markers on the map to show community activity
//

import Foundation
import CoreLocation

/// Lightweight marker for community places (saved by users you don't follow)
struct CommunityPlaceMarker: Identifiable, Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let saveCount: Int
    let placeType: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Returns an emoji representing the place type
    var emoji: String {
        PlaceTypeEmoji.emoji(for: placeType)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude
        case saveCount = "save_count"
        case placeType = "place_type"
    }
}

/// Maps place types to appropriate emojis
struct PlaceTypeEmoji {
    static func emoji(for placeType: String) -> String {
        let type = placeType.lowercased()
        
        // Food & Dining
        if type.contains("restaurant") || type.contains("food") { return "🍽️" }
        if type.contains("coffee") || type.contains("cafe") { return "☕" }
        if type.contains("tea") { return "🍵" }
        if type.contains("bar") || type.contains("pub") || type.contains("brewery") { return "🍺" }
        if type.contains("pizza") { return "🍕" }
        if type.contains("burger") { return "🍔" }
        if type.contains("sushi") || type.contains("japanese") { return "🍣" }
        if type.contains("mexican") || type.contains("taco") { return "🌮" }
        if type.contains("chinese") || type.contains("asian") { return "🥡" }
        if type.contains("italian") || type.contains("pasta") { return "🍝" }
        if type.contains("indian") { return "🍛" }
        if type.contains("thai") || type.contains("vietnamese") { return "🍜" }
        if type.contains("bakery") || type.contains("dessert") { return "🧁" }
        if type.contains("ice cream") { return "🍦" }
        if type.contains("steakhouse") || type.contains("bbq") || type.contains("barbecue") { return "🥩" }
        if type.contains("seafood") { return "🦞" }
        
        // Parks & Nature
        if type.contains("park") || type.contains("garden") { return "🌳" }
        if type.contains("beach") { return "🏖️" }
        if type.contains("mountain") || type.contains("hiking") || type.contains("trail") { return "⛰️" }
        if type.contains("lake") || type.contains("river") { return "🏞️" }
        if type.contains("zoo") { return "🦁" }
        if type.contains("aquarium") { return "🐠" }
        
        // Entertainment
        if type.contains("movie") || type.contains("theater") || type.contains("cinema") { return "🎬" }
        if type.contains("museum") || type.contains("gallery") { return "🏛️" }
        if type.contains("concert") || type.contains("music") { return "🎵" }
        if type.contains("stadium") || type.contains("arena") { return "🏟️" }
        if type.contains("gym") || type.contains("fitness") { return "💪" }
        if type.contains("spa") { return "💆" }
        if type.contains("golf") { return "⛳" }
        if type.contains("bowling") { return "🎳" }
        if type.contains("arcade") || type.contains("game") { return "🎮" }
        
        // Shopping
        if type.contains("mall") || type.contains("shopping") { return "🛍️" }
        if type.contains("grocery") || type.contains("market") { return "🛒" }
        if type.contains("bookstore") || type.contains("library") { return "📚" }
        
        // Services & Transport
        if type.contains("hotel") || type.contains("resort") || type.contains("lodge") { return "🏨" }
        if type.contains("airport") { return "✈️" }
        if type.contains("train") || type.contains("station") { return "🚂" }
        if type.contains("hospital") || type.contains("medical") { return "🏥" }
        if type.contains("gas") || type.contains("fuel") { return "⛽" }
        
        // Religious & Cultural
        if type.contains("church") || type.contains("cathedral") { return "⛪" }
        if type.contains("temple") || type.contains("shrine") { return "🛕" }
        if type.contains("mosque") { return "🕌" }
        if type.contains("monument") || type.contains("landmark") { return "🗽" }
        if type.contains("castle") || type.contains("palace") { return "🏰" }
        
        // Default
        return "📍"
    }
}

