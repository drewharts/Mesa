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
        
        // Food & Dining - specific types first (order matters!)
        if type.contains("pizza") { return "🍕" }
        if type.contains("burger") { return "🍔" }
        if type.contains("sushi") { return "🍣" }
        if type.contains("ramen") || type.contains("noodle") { return "🍜" }
        if type.contains("poke") { return "🐟" }
        if type.contains("taco") || type.contains("mexican") || type.contains("burrito") { return "🌮" }
        if type.contains("dim sum") || type.contains("dumpling") { return "🥟" }
        if type.contains("korean") { return "🍖" }
        if type.contains("chinese") { return "🥡" }
        if type.contains("japanese") { return "🍣" }
        if type.contains("thai") || type.contains("vietnamese") { return "🍜" }
        if type.contains("indian") || type.contains("curry") { return "🍛" }
        if type.contains("italian") || type.contains("pasta") { return "🍝" }
        if type.contains("mediterranean") || type.contains("greek") { return "🥙" }
        if type.contains("steakhouse") || type.contains("bbq") || type.contains("barbecue") { return "🥩" }
        if type.contains("seafood") || type.contains("fish") || type.contains("oyster") { return "🦞" }
        if type.contains("wing") || type.contains("chicken") { return "🍗" }
        if type.contains("sandwich") || type.contains("deli") || type.contains("sub") { return "🥪" }
        if type.contains("salad") || type.contains("acai") { return "🥗" }
        if type.contains("soup") || type.contains("pho") { return "🍲" }
        if type.contains("hot dog") { return "🌭" }
        if type.contains("donut") || type.contains("doughnut") { return "🍩" }
        if type.contains("brunch") || type.contains("breakfast") || type.contains("pancake") || type.contains("waffle") { return "🥞" }
        if type.contains("bakery") || type.contains("pastry") { return "🧁" }
        if type.contains("dessert") || type.contains("sweet") { return "🍰" }
        if type.contains("ice cream") || type.contains("gelato") || type.contains("frozen yogurt") { return "🍦" }
        if type.contains("juice") || type.contains("smoothie") { return "🧃" }
        if type.contains("coffee") || type.contains("cafe") || type.contains("espresso") { return "☕" }
        if type.contains("tea") { return "🍵" }
        if type.contains("wine") || type.contains("winery") { return "🍷" }
        if type.contains("cocktail") { return "🍸" }
        if type.contains("bar") || type.contains("pub") || type.contains("brewery") || type.contains("beer") { return "🍺" }
        if type.contains("asian") { return "🥢" }
        if type.contains("restaurant") || type.contains("food") || type.contains("dining") { return "🍽️" }
        
        // Shopping - Clothing & Fashion
        if type.contains("clothing") || type.contains("apparel") || type.contains("fashion") { return "👕" }
        if type.contains("shoe") || type.contains("footwear") || type.contains("sneaker") { return "👟" }
        if type.contains("jewelry") || type.contains("jeweler") { return "💎" }
        if type.contains("watch") { return "⌚" }
        if type.contains("handbag") || type.contains("purse") || type.contains("bag") { return "👜" }
        if type.contains("hat") || type.contains("cap") { return "🧢" }
        if type.contains("sunglasses") || type.contains("eyewear") || type.contains("optical") { return "🕶️" }
        if type.contains("lingerie") || type.contains("underwear") { return "👙" }
        if type.contains("bridal") || type.contains("wedding") { return "👰" }
        if type.contains("vintage") || type.contains("thrift") || type.contains("consignment") { return "🏷️" }
        if type.contains("boutique") { return "👗" }
        
        // Shopping - Electronics & Tech
        if type.contains("electronics") || type.contains("computer") || type.contains("tech") { return "💻" }
        if type.contains("phone") || type.contains("mobile") || type.contains("cellular") { return "📱" }
        if type.contains("camera") || type.contains("photo") { return "📷" }
        if type.contains("video game") || type.contains("gaming") { return "🎮" }
        
        // Shopping - Home & Garden
        if type.contains("furniture") || type.contains("home decor") { return "🛋️" }
        if type.contains("hardware") || type.contains("tool") { return "🔧" }
        if type.contains("plant") || type.contains("nursery") || type.contains("florist") { return "🌸" }
        if type.contains("home goods") || type.contains("housewares") { return "🏠" }
        if type.contains("mattress") || type.contains("bedding") { return "🛏️" }
        if type.contains("kitchen") || type.contains("appliance") { return "🍳" }
        if type.contains("lighting") || type.contains("lamp") { return "💡" }
        
        // Shopping - Specialty
        if type.contains("pet") || type.contains("animal") { return "🐾" }
        if type.contains("toy") { return "🧸" }
        if type.contains("sport") || type.contains("athletic") { return "⚽" }
        if type.contains("outdoor") || type.contains("camping") { return "🏕️" }
        if type.contains("bike") || type.contains("bicycle") || type.contains("cycling") { return "🚴" }
        if type.contains("music store") || type.contains("instrument") || type.contains("guitar") { return "🎸" }
        if type.contains("record") || type.contains("vinyl") { return "💿" }
        if type.contains("art supply") || type.contains("craft") { return "🎨" }
        if type.contains("gift") || type.contains("souvenir") { return "🎁" }
        if type.contains("candle") || type.contains("aromatherapy") { return "🕯️" }
        if type.contains("cosmetic") || type.contains("makeup") || type.contains("beauty") { return "💄" }
        if type.contains("pharmacy") || type.contains("drugstore") { return "💊" }
        if type.contains("smoke") || type.contains("vape") || type.contains("tobacco") { return "🚬" }
        if type.contains("liquor") || type.contains("alcohol") || type.contains("wine store") { return "🍾" }
        if type.contains("convenience") { return "🏪" }
        if type.contains("department store") { return "🏬" }
        if type.contains("outlet") || type.contains("discount") { return "🏷️" }
        if type.contains("bookstore") || type.contains("book shop") { return "📚" }
        if type.contains("stationery") || type.contains("office supply") { return "📝" }
        if type.contains("grocery") || type.contains("supermarket") { return "🛒" }
        if type.contains("farmer") || type.contains("organic") { return "🥬" }
        if type.contains("butcher") || type.contains("meat") { return "🥓" }
        if type.contains("seafood market") || type.contains("fish market") { return "🐟" }
        if type.contains("candy") || type.contains("chocolate") { return "🍬" }
        if type.contains("mall") || type.contains("shopping center") { return "🛍️" }
        
        // Beauty & Personal Care
        if type.contains("salon") || type.contains("hair") || type.contains("barber") { return "💇" }
        if type.contains("nail") || type.contains("manicure") { return "💅" }
        if type.contains("spa") || type.contains("massage") || type.contains("wellness") { return "💆" }
        if type.contains("tattoo") || type.contains("piercing") { return "🖋️" }
        if type.contains("tanning") { return "☀️" }
        if type.contains("wax") || type.contains("laser") { return "✨" }
        
        // Parks & Nature
        if type.contains("national park") { return "🏞️" }
        if type.contains("botanical") || type.contains("garden") { return "🌷" }
        if type.contains("park") { return "🌳" }
        if type.contains("beach") || type.contains("coast") { return "🏖️" }
        if type.contains("mountain") || type.contains("hiking") || type.contains("trail") { return "⛰️" }
        if type.contains("lake") || type.contains("river") || type.contains("waterfall") { return "🏞️" }
        if type.contains("forest") || type.contains("wood") { return "🌲" }
        if type.contains("desert") { return "🏜️" }
        if type.contains("zoo") { return "🦁" }
        if type.contains("aquarium") { return "🐠" }
        if type.contains("wildlife") || type.contains("sanctuary") { return "🦌" }
        if type.contains("farm") || type.contains("ranch") { return "🚜" }
        
        // Entertainment & Activities
        if type.contains("movie") || type.contains("cinema") { return "🎬" }
        if type.contains("theater") || type.contains("theatre") || type.contains("performing art") { return "🎭" }
        if type.contains("museum") { return "🏛️" }
        if type.contains("art gallery") || type.contains("gallery") { return "🖼️" }
        if type.contains("concert") || type.contains("live music") || type.contains("venue") { return "🎵" }
        if type.contains("night club") || type.contains("club") || type.contains("disco") { return "🪩" }
        if type.contains("karaoke") { return "🎤" }
        if type.contains("comedy") || type.contains("improv") { return "😂" }
        if type.contains("casino") || type.contains("gambling") { return "🎰" }
        if type.contains("escape room") || type.contains("puzzle") { return "🔐" }
        if type.contains("laser tag") || type.contains("paintball") { return "🔫" }
        if type.contains("trampoline") || type.contains("bounce") { return "🤸" }
        if type.contains("mini golf") || type.contains("putt") { return "⛳" }
        if type.contains("go kart") || type.contains("racing") { return "🏎️" }
        if type.contains("amusement") || type.contains("theme park") || type.contains("roller coaster") { return "🎢" }
        if type.contains("water park") { return "🌊" }
        if type.contains("carnival") || type.contains("fair") { return "🎡" }
        if type.contains("circus") { return "🎪" }
        
        // Sports & Fitness
        if type.contains("gym") || type.contains("fitness") || type.contains("crossfit") { return "💪" }
        if type.contains("yoga") || type.contains("pilates") { return "🧘" }
        if type.contains("boxing") || type.contains("martial art") || type.contains("mma") { return "🥊" }
        if type.contains("swimming") || type.contains("pool") { return "🏊" }
        if type.contains("tennis") { return "🎾" }
        if type.contains("basketball") { return "🏀" }
        if type.contains("soccer") || type.contains("football field") { return "⚽" }
        if type.contains("baseball") { return "⚾" }
        if type.contains("golf") || type.contains("driving range") { return "⛳" }
        if type.contains("bowling") { return "🎳" }
        if type.contains("skating") || type.contains("roller") { return "⛸️" }
        if type.contains("ski") || type.contains("snowboard") { return "⛷️" }
        if type.contains("surf") { return "🏄" }
        if type.contains("rock climb") || type.contains("bouldering") { return "🧗" }
        if type.contains("stadium") || type.contains("arena") { return "🏟️" }
        if type.contains("arcade") || type.contains("game") { return "🎮" }
        
        // Services & Professional
        if type.contains("bank") || type.contains("atm") || type.contains("credit union") { return "🏦" }
        if type.contains("lawyer") || type.contains("attorney") || type.contains("legal") { return "⚖️" }
        if type.contains("accountant") || type.contains("tax") { return "🧮" }
        if type.contains("real estate") || type.contains("realtor") { return "🏡" }
        if type.contains("insurance") { return "🛡️" }
        if type.contains("dentist") || type.contains("dental") { return "🦷" }
        if type.contains("doctor") || type.contains("clinic") || type.contains("physician") { return "👨‍⚕️" }
        if type.contains("hospital") || type.contains("emergency") { return "🏥" }
        if type.contains("veterinar") || type.contains("vet") || type.contains("animal hospital") { return "🐕" }
        if type.contains("eye") || type.contains("optometrist") || type.contains("vision") { return "👁️" }
        if type.contains("chiropract") { return "🦴" }
        if type.contains("physical therap") || type.contains("rehab") { return "🏃" }
        if type.contains("psycholog") || type.contains("therapist") || type.contains("counselor") { return "🧠" }
        if type.contains("laundry") || type.contains("dry clean") { return "👔" }
        if type.contains("tailor") || type.contains("alteration") { return "🪡" }
        if type.contains("car wash") { return "🚗" }
        if type.contains("auto") || type.contains("mechanic") || type.contains("car repair") { return "🔧" }
        if type.contains("tire") { return "🛞" }
        if type.contains("parking") { return "🅿️" }
        if type.contains("storage") { return "📦" }
        if type.contains("shipping") || type.contains("mail") || type.contains("post office") { return "📮" }
        if type.contains("print") || type.contains("copy") { return "🖨️" }
        if type.contains("locksmith") { return "🔑" }
        if type.contains("moving") { return "📦" }
        if type.contains("cleaning") || type.contains("maid") { return "🧹" }
        if type.contains("plumber") || type.contains("plumbing") { return "🚿" }
        if type.contains("electric") { return "⚡" }
        if type.contains("hvac") || type.contains("air condition") || type.contains("heating") { return "❄️" }
        
        // Transport & Travel
        if type.contains("hotel") || type.contains("motel") || type.contains("inn") || type.contains("lodging") { return "🏨" }
        if type.contains("resort") { return "🏝️" }
        if type.contains("hostel") { return "🛏️" }
        if type.contains("airbnb") || type.contains("vacation rental") { return "🏠" }
        if type.contains("airport") || type.contains("aviation") { return "✈️" }
        if type.contains("train") || type.contains("rail") { return "🚂" }
        if type.contains("bus") || type.contains("transit") { return "🚌" }
        if type.contains("subway") || type.contains("metro") { return "🚇" }
        if type.contains("ferry") || type.contains("boat") { return "⛴️" }
        if type.contains("car rental") || type.contains("rent a car") { return "🚙" }
        if type.contains("taxi") || type.contains("cab") || type.contains("rideshare") { return "🚕" }
        if type.contains("gas") || type.contains("fuel") || type.contains("petrol") { return "⛽" }
        if type.contains("ev charging") || type.contains("charging station") { return "🔌" }
        if type.contains("travel agent") || type.contains("tour") { return "🗺️" }
        
        // Education
        if type.contains("school") || type.contains("elementary") || type.contains("high school") { return "🏫" }
        if type.contains("university") || type.contains("college") { return "🎓" }
        if type.contains("library") { return "📚" }
        if type.contains("tutoring") || type.contains("learning") { return "📖" }
        if type.contains("driving school") { return "🚗" }
        if type.contains("dance") || type.contains("ballet") { return "💃" }
        if type.contains("music school") || type.contains("music lesson") { return "🎹" }
        if type.contains("art school") || type.contains("art class") { return "🎨" }
        if type.contains("language") || type.contains("esl") { return "🗣️" }
        if type.contains("daycare") || type.contains("preschool") || type.contains("childcare") { return "👶" }
        
        // Religious & Cultural
        if type.contains("church") || type.contains("cathedral") || type.contains("chapel") { return "⛪" }
        if type.contains("temple") || type.contains("buddhist") { return "🛕" }
        if type.contains("mosque") || type.contains("islamic") { return "🕌" }
        if type.contains("synagogue") || type.contains("jewish") { return "🕍" }
        if type.contains("hindu") { return "🕉️" }
        if type.contains("cemetery") || type.contains("funeral") { return "🪦" }
        if type.contains("monument") || type.contains("memorial") { return "🗽" }
        if type.contains("landmark") || type.contains("historic") { return "🏛️" }
        if type.contains("castle") || type.contains("palace") || type.contains("fortress") { return "🏰" }
        
        // Government & Public
        if type.contains("city hall") || type.contains("government") || type.contains("municipal") { return "🏛️" }
        if type.contains("court") || type.contains("courthouse") { return "⚖️" }
        if type.contains("police") { return "🚔" }
        if type.contains("fire") || type.contains("firehouse") { return "🚒" }
        if type.contains("embassy") || type.contains("consulate") { return "🏛️" }
        if type.contains("community center") || type.contains("rec center") { return "🏢" }
        
        // Default
        return "📍"
    }
}

