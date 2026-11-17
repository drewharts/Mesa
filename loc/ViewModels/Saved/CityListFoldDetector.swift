//
//  CityListFoldDetector.swift
//  loc
//
//  Pure rules for spotting user lists that are only "city + type" (e.g. "NYC Restaurants",
//  "Tokyo coffee", "Paris bars", "Brooklyn") and are fully covered by the Saved library, so they can be
//  folded into their city. Never deletes or edits anything: the result is just a set of list ids to hide.
//  Unit tested in CityListFoldDetectorTests.
//

import Foundation

/// What the detector needs to know about one of the user's own lists.
struct FoldCandidateList: Equatable {
    var id: String
    var name: String
    var isPublic: Bool
    /// Shared with the user, or shared with collaborators.
    var isCollaborative: Bool
    var isPaid: Bool
    /// Lowercased ids of the places in the list; nil when they could not be read.
    var placeIds: Set<String>?
}

enum FoldKeepReason: Equatable {
    case isPublic, collaborative, paid
    case membershipUnknown, empty, placesNotInLibrary
    case nameNotCityOrType, nameDoesNotMatchPlaces
}

enum FoldDecision: Equatable {
    case fold
    case keep(FoldKeepReason)

    var isFold: Bool { self == .fold }
}

enum CityListFoldDetector {
    /// Share of a list's places that must sit in the city the name mentions.
    static let minCityShare = 0.5
    /// Share of a list's places that must fit the type / cuisine the name mentions.
    static let minTypeShare = 0.6

    /// Decides, per list id, whether the list folds into the library's cities.
    static func detect(_ lists: [FoldCandidateList], library: SavedLibrary) -> [String: FoldDecision] {
        var index: [String: SavedLibraryPlace] = [:]
        for city in library.cities {
            for place in city.places { for alias in place.aliasIds { index[alias] = place } }
        }
        var decisions: [String: FoldDecision] = [:]
        for list in lists { decisions[list.id] = decide(list, index: index) }
        return decisions
    }

    /// Ids of the lists that fold, in input order.
    static func foldedIds(_ lists: [FoldCandidateList], library: SavedLibrary) -> [String] {
        let decisions = detect(lists, library: library)
        return lists.filter { decisions[$0.id]?.isFold == true }.map(\.id)
    }

    // MARK: - Decision

    /// Applies the keep-visible guards first, then the name and place checks.
    private static func decide(_ list: FoldCandidateList, index: [String: SavedLibraryPlace]) -> FoldDecision {
        if let guardReason = guardReason(for: list) { return .keep(guardReason) }
        guard let ids = list.placeIds else { return .keep(.membershipUnknown) }
        guard !ids.isEmpty else { return .keep(.empty) }
        let places = ids.compactMap { index[$0] }
        guard places.count == ids.count else { return .keep(.placesNotInLibrary) }
        guard let name = parseName(list.name, places: places) else { return .keep(.nameNotCityOrType) }
        guard cityShare(name, places) >= minCityShare else { return .keep(.nameDoesNotMatchPlaces) }
        guard typeShare(name, places) >= minTypeShare else { return .keep(.nameDoesNotMatchPlaces) }
        return .fold
    }

    /// Lists others can reach (public, shared, paid) always stay visible so links keep working.
    private static func guardReason(for list: FoldCandidateList) -> FoldKeepReason? {
        if list.isPublic { return .isPublic }
        if list.isCollaborative { return .collaborative }
        if list.isPaid { return .paid }
        return nil
    }

    // MARK: - Name parsing

    /// What a list name says: the cities it names and the types / cuisines it names.
    struct ParsedName: Equatable {
        var cityPhrases: Set<String> = []
        var types: Set<SavedPlaceType> = []
        var cuisines: Set<String> = []
    }

    /// Reads a list name made only of city names, type words, cuisine words and filler. Nil for anything else
    /// ("Date night", "Mom's picks") or when the name says no city, type or cuisine at all.
    static func parseName(_ name: String, places: [SavedLibraryPlace]) -> ParsedName? {
        var vocabulary: [String: Category] = [:]
        for phrase in stopPhrases { vocabulary[phrase] = .filler }
        for (phrase, type) in typePhrases { vocabulary[phrase] = .type(type) }
        for (phrase, cuisine) in cuisinePhrases { vocabulary[phrase] = .cuisine(cuisine) }
        for phrase in cityPhrases(of: places) { vocabulary[phrase] = .city }

        var text = " " + SavedLibraryBuilder.foldKey(name) + " "
        var parsed = ParsedName()
        let ordered = vocabulary.keys.sorted { a, b in
            let (wa, wb) = (a.split(separator: " ").count, b.split(separator: " ").count)
            return wa != wb ? wa > wb : (a.count != b.count ? a.count > b.count : a < b)
        }
        for phrase in ordered {
            while let range = text.range(of: " \(phrase) ") {
                text.replaceSubrange(range, with: " ")
                record(vocabulary[phrase]!, phrase: phrase, in: &parsed)
            }
        }
        let leftover = text.trimmingCharacters(in: .whitespaces)
        let saysSomething = !parsed.cityPhrases.isEmpty || !parsed.types.isEmpty || !parsed.cuisines.isEmpty
        return leftover.isEmpty && saysSomething ? parsed : nil
    }

    private enum Category { case filler, city, type(SavedPlaceType), cuisine(String) }

    /// Adds a consumed phrase to the parsed result under its category.
    private static func record(_ category: Category, phrase: String, in parsed: inout ParsedName) {
        switch category {
        case .filler: break
        case .city: parsed.cityPhrases.insert(phrase)
        case .type(let type): parsed.types.insert(type)
        case .cuisine(let cuisine): parsed.cuisines.insert(SavedLibraryBuilder.foldKey(cuisine))
        }
    }

    // MARK: - Place checks

    /// Share of places whose city or area is one of the cities the name mentions (1 when the name names no city).
    private static func cityShare(_ name: ParsedName, _ places: [SavedLibraryPlace]) -> Double {
        guard !name.cityPhrases.isEmpty else { return 1 }
        let hits = places.filter { !cityPhrases(of: [$0]).isDisjoint(with: name.cityPhrases) }.count
        return Double(hits) / Double(places.count)
    }

    /// Share of places that fit the types / cuisines the name mentions (1 when the name names none).
    private static func typeShare(_ name: ParsedName, _ places: [SavedLibraryPlace]) -> Double {
        guard !name.types.isEmpty || !name.cuisines.isEmpty else { return 1 }
        let hits = places.filter { fits($0, name) }.count
        return Double(hits) / Double(places.count)
    }

    /// "Italian restaurants" needs an Italian restaurant; "Italian & bars" takes either.
    private static func fits(_ place: SavedLibraryPlace, _ name: ParsedName) -> Bool {
        let cuisineMatch = place.type == .restaurants && place.cuisine.map { name.cuisines.contains(SavedLibraryBuilder.foldKey($0)) } == true
        if name.cuisines.isEmpty { return name.types.contains(place.type) }
        if name.types.isSubset(of: [.restaurants]) { return cuisineMatch }
        return cuisineMatch || name.types.contains(place.type)
    }

    // MARK: - City phrases

    /// Folded names a place can be called: its city, its area, and the nicknames of those ("nyc", "sf").
    static func cityPhrases(of places: [SavedLibraryPlace]) -> Set<String> {
        var phrases = Set<String>()
        for place in places {
            for raw in [place.city, place.area ?? ""] where !raw.isEmpty && raw != SavedLibraryBuilder.unknownCityName {
                let key = SavedLibraryBuilder.foldKey(raw)
                guard !key.isEmpty else { continue }
                phrases.insert(key)
                phrases.formUnion(cityNicknames[key] ?? [])
            }
        }
        return phrases
    }

    static let cityNicknames: [String: Set<String>] = [
        "new york city": ["nyc", "new york", "ny", "new york ny"],
        "los angeles": ["la", "l a"],
        "san francisco": ["sf", "san fran"],
        "washington": ["dc", "d c", "washington dc"],
        "philadelphia": ["philly"],
        "las vegas": ["vegas"],
        "new orleans": ["nola"],
        "mexico city": ["cdmx"],
        "montreal": ["mtl"]
    ]

    // MARK: - Vocabulary

    /// Filler words that may sit around a city / type ("My NYC places", "Places to eat in Paris").
    static let stopPhrases: Set<String> = ["the", "a", "my", "in", "of", "and", "to", "eat", "places", "place", "spots", "spot", "list"]

    static let typePhrases: [String: SavedPlaceType] = {
        let table: [SavedPlaceType: [String]] = [
            .restaurants: ["restaurants", "restaurant", "food", "eats", "dinner", "lunch", "brunch", "breakfast", "dining"],
            .bars: ["bars", "bar", "cocktails", "cocktail bars", "nightlife", "drinks", "wine", "wine bars", "pubs", "pub", "breweries"],
            .coffee: ["coffee", "coffee shops", "coffee shop", "cafes", "cafe", "bakeries", "bakery", "dessert", "desserts", "sweets", "tea", "ice cream"],
            .shops: ["shops", "shop", "shopping", "stores", "store", "boutiques", "markets"],
            .sights: ["sights", "sightseeing", "museums", "museum", "parks", "park", "attractions", "landmarks", "things to do", "hikes", "hiking", "activities"],
            .stays: ["stays", "hotels", "hotel", "lodging", "accommodation"]
        ]
        var result: [String: SavedPlaceType] = [:]
        for (type, words) in table { for word in words { result[word] = type } }
        return result
    }()

    /// Cuisine words -> the cuisine label SavedLibraryBuilder gives a restaurant.
    static let cuisinePhrases: [String: String] = {
        var result: [String: String] = [
            "pizza": "Pizza", "sushi": "Sushi", "ramen": "Ramen", "tacos": "Mexican", "taco": "Mexican",
            "bbq": "Barbecue", "barbecue": "Barbecue", "burgers": "Burgers", "burger": "Burgers",
            "steakhouses": "Steakhouse", "steakhouse": "Steakhouse", "seafood": "Seafood",
            "dumplings": "Dumplings", "noodles": "Noodles", "bagels": "Bagels", "sandwiches": "Sandwiches"
        ]
        let plain = ["italian", "japanese", "chinese", "mexican", "thai", "korean", "indian", "french", "vietnamese",
                     "mediterranean", "greek", "spanish", "american", "middle eastern", "ethiopian", "turkish",
                     "lebanese", "peruvian", "brazilian", "german", "british", "cuban", "caribbean", "vegan",
                     "vegetarian", "african", "persian", "taiwanese", "filipino", "indonesian", "malaysian", "asian"]
        for word in plain { result[word] = word.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ") }
        return result
    }()
}
