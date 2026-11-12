//
//  SavedLibraryBuilder.swift
//  loc
//
//  PROTOTYPE (auto_sort_saved). Pure, on-device sorting of the places a user already has
//  (list items, favorites, my places, imports) into a "Saved" library:
//  city -> type (Restaurants, Bars, Coffee & Sweets, Shops, Sights, Stays, Other) -> cuisine,
//  plus smart groups (Near you, Saved this week, Dinner in <city>).
//  Read-only: no network, no writes, no new tables. Unit tested in SavedLibraryBuilderTests.
//

import Foundation

// MARK: - Input

/// One place the user has, flattened from DetailPlace / imports. Foundation-only so it is easy to test.
struct SavedPlaceInput: Equatable {
    enum Source: String, Hashable { case list, imported, myPlace }

    var id: String
    var name: String
    var address: String?
    var storedCity: String?
    var latitude: Double?
    var longitude: Double?
    var categories: [String]
    var userCorrectedCategory: String?
    var googlePlaceId: String?
    /// True when the place works for dinner (decided by TonightCategoryClassifier in the adapter).
    var isDinnerSpot: Bool = false
    /// When the user added it; only imports carry this (place_list_items has no created_at).
    var addedAt: Date?
    var sources: Set<Source> = []
}

// MARK: - Output

enum SavedPlaceType: String, CaseIterable, Hashable, Identifiable {
    case restaurants, bars, coffee, shops, sights, stays, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .restaurants: return "Restaurants"
        case .bars: return "Bars"
        case .coffee: return "Coffee & Sweets"
        case .shops: return "Shops"
        case .sights: return "Sights"
        case .stays: return "Stays"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .restaurants: return "fork.knife"
        case .bars: return "wineglass"
        case .coffee: return "cup.and.saucer"
        case .shops: return "bag"
        case .sights: return "binoculars"
        case .stays: return "bed.double"
        case .other: return "mappin"
        }
    }
}

struct SavedLibraryPlace: Identifiable, Equatable {
    var id: String
    var name: String
    var address: String?
    var latitude: Double?
    var longitude: Double?
    /// Display city ("New York City", "Paris").
    var city: String
    /// Finer area when the city was merged or aliased (e.g. "Brooklyn" inside New York City).
    var area: String?
    var type: SavedPlaceType
    var cuisine: String?
    var isDinnerSpot: Bool
    var addedAt: Date?
    var distanceMeters: Double?
    var sources: Set<SavedPlaceInput.Source>
}

struct SavedCityGroup: Identifiable, Equatable {
    var id: String { key }
    var key: String
    var name: String
    var places: [SavedLibraryPlace]

    var typeCounts: [(type: SavedPlaceType, count: Int)] {
        SavedPlaceType.allCases.compactMap { t in
            let n = places.filter { $0.type == t }.count
            return n > 0 ? (t, n) : nil
        }
    }

    static func == (a: SavedCityGroup, b: SavedCityGroup) -> Bool { a.key == b.key && a.places == b.places }
}

struct SavedSmartGroup: Identifiable, Equatable {
    enum Kind: Hashable { case nearYou, thisWeek, dinner }
    var kind: Kind
    var title: String
    var places: [SavedLibraryPlace]
    var id: String { title }
}

struct SavedLibrary: Equatable {
    var cities: [SavedCityGroup]
    var smartGroups: [SavedSmartGroup]
    var totalCount: Int

    static let empty = SavedLibrary(cities: [], smartGroups: [], totalCount: 0)
}

// MARK: - Builder

enum SavedLibraryBuilder {
    /// "Near you" radius: 20 miles.
    static let nearRadiusMeters: Double = 32_187
    /// A city with fewer places than this can be folded into a bigger city nearby.
    static let smallCityThreshold = 3
    /// How close a small city's center must be to a bigger city to be folded in.
    static let mergeRadiusMeters: Double = 25_000
    /// Places with no city at all join the nearest city within this distance.
    static let orphanRadiusMeters: Double = 40_000
    static let unknownCityName = "Other places"

    /// Builds the whole library. `userLocation` is (lat, lon) when location is on.
    static func build(_ inputs: [SavedPlaceInput], userLocation: (lat: Double, lon: Double)?, now: Date = Date()) -> SavedLibrary {
        let unique = dedupe(inputs)

        // 1. Classify and find a raw city for each place.
        var places: [SavedLibraryPlace] = unique.map { input in
            let located = city(storedCity: input.storedCity, address: input.address)
            let type = classify(categories: input.categories, corrected: input.userCorrectedCategory, name: input.name)
            var distance: Double?
            if let user = userLocation, let lat = input.latitude, let lon = input.longitude {
                distance = distanceMeters(user.lat, user.lon, lat, lon)
            }
            return SavedLibraryPlace(
                id: input.id, name: input.name, address: input.address,
                latitude: input.latitude, longitude: input.longitude,
                city: located?.city ?? "", area: located?.area,
                type: type,
                cuisine: type == .restaurants ? cuisine(categories: input.categories, corrected: input.userCorrectedCategory, name: input.name) : nil,
                isDinnerSpot: input.isDinnerSpot && type == .restaurants,
                addedAt: input.addedAt, distanceMeters: distance, sources: input.sources
            )
        }

        // 2. Group by city key, fold small cities and orphans into nearby big ones.
        places = consolidateCities(places)
        var byKey: [String: [SavedLibraryPlace]] = [:]
        for p in places { byKey[cityKey(p.city), default: []].append(p) }
        var cities: [SavedCityGroup] = byKey.map { key, list in
            SavedCityGroup(key: key, name: list.first?.city ?? unknownCityName, places: sortPlaces(list))
        }
        cities.sort { a, b in
            if (a.name == unknownCityName) != (b.name == unknownCityName) { return b.name == unknownCityName }
            if a.places.count != b.places.count { return a.places.count > b.places.count }
            return a.name < b.name
        }

        // 3. Smart groups.
        var smart: [SavedSmartGroup] = []
        if userLocation != nil {
            let near = places.filter { ($0.distanceMeters ?? .infinity) <= nearRadiusMeters }
                .sorted { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }
            if !near.isEmpty { smart.append(SavedSmartGroup(kind: .nearYou, title: "Near you", places: near)) }
        }
        let weekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let recent = places.filter { ($0.addedAt ?? .distantPast) >= weekAgo }
            .sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
        if !recent.isEmpty { smart.append(SavedSmartGroup(kind: .thisWeek, title: "Saved this week", places: recent)) }
        if let dinnerCity = homeCity(cities: cities, places: places, userLocation: userLocation) {
            let dinner = dinnerCity.places.filter { $0.isDinnerSpot }
            if dinner.count >= 2 {
                let sorted = userLocation == nil ? dinner : dinner.sorted { ($0.distanceMeters ?? .infinity) < ($1.distanceMeters ?? .infinity) }
                smart.append(SavedSmartGroup(kind: .dinner, title: "Dinner in \(shortCityName(dinnerCity.name))", places: sorted))
            }
        }

        return SavedLibrary(cities: cities, smartGroups: smart, totalCount: places.count)
    }

    // MARK: Dedupe

    /// Merges the same place showing up in several lists / imports (by id, Google id, or same name within ~75 m).
    static func dedupe(_ inputs: [SavedPlaceInput]) -> [SavedPlaceInput] {
        var result: [SavedPlaceInput] = []
        var indexById: [String: Int] = [:]
        var indexByGoogle: [String: Int] = [:]
        var indexByName: [String: [Int]] = [:]

        for input in inputs {
            let idKey = input.id.lowercased()
            let googleKey = input.googlePlaceId.flatMap { $0.isEmpty ? nil : $0 }
            let nameKey = foldKey(input.name)
            var match: Int? = indexById[idKey] ?? googleKey.flatMap { indexByGoogle[$0] }
            if match == nil, !nameKey.isEmpty, let lat = input.latitude, let lon = input.longitude {
                match = indexByName[nameKey]?.first { i in
                    guard let la = result[i].latitude, let lo = result[i].longitude else { return false }
                    return distanceMeters(lat, lon, la, lo) < 75
                }
            }
            if let i = match {
                result[i] = merge(result[i], input)
            } else {
                result.append(input)
                match = result.count - 1
            }
            let i = match!
            indexById[idKey] = i
            if let g = googleKey { indexByGoogle[g] = i }
            if !nameKey.isEmpty, !(indexByName[nameKey]?.contains(i) ?? false) { indexByName[nameKey, default: []].append(i) }
        }
        return result
    }

    private static func merge(_ a: SavedPlaceInput, _ b: SavedPlaceInput) -> SavedPlaceInput {
        var m = a
        m.sources.formUnion(b.sources)
        if m.address?.isEmpty ?? true { m.address = b.address }
        if m.storedCity?.isEmpty ?? true { m.storedCity = b.storedCity }
        if m.latitude == nil { m.latitude = b.latitude; m.longitude = b.longitude }
        if m.categories.isEmpty { m.categories = b.categories }
        if m.userCorrectedCategory == nil { m.userCorrectedCategory = b.userCorrectedCategory }
        if m.googlePlaceId == nil { m.googlePlaceId = b.googlePlaceId }
        m.isDinnerSpot = m.isDinnerSpot || b.isDinnerSpot
        switch (m.addedAt, b.addedAt) {
        case (nil, let d): m.addedAt = d
        case (let x?, let y?): m.addedAt = max(x, y)
        default: break
        }
        return m
    }

    // MARK: City

    /// New York City boroughs/neighborhoods that Google reports as the locality.
    static let nycAreas: Set<String> = [
        "manhattan", "brooklyn", "queens", "bronx", "the bronx", "staten island", "flushing", "astoria",
        "long island city", "jackson heights", "elmhurst", "east elmhurst", "forest hills", "ridgewood",
        "sunnyside", "woodside", "corona", "jamaica", "bayside", "rego park", "kew gardens", "college point",
        "whitestone", "fresh meadows", "howard beach", "far rockaway", "rockaway beach", "maspeth",
        "middle village", "glendale", "ozone park", "richmond hill", "williamsburg", "greenpoint", "bushwick"
    ]
    static let nycNames: Set<String> = ["new york", "new york city", "nyc", "new york ny"]

    /// Picks a display city (and finer area) from the stored city field, else the address. No geocoding.
    static func city(storedCity: String?, address: String?) -> (city: String, area: String?)? {
        var stored = storedCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parsed = locality(fromAddress: address)
        // A stored "Kings County" / "Greece" / "Oregon" is coarser than the address's locality.
        let storedKey = foldKey(stored)
        if countryNames.contains(storedKey) || usStateNames.contains(storedKey) || storedKey.hasSuffix(" county") {
            if parsed != nil || !storedKey.hasSuffix(" county") { stored = "" }
        }
        if stored.hasPrefix("Greater ") { stored = String(stored.dropFirst("Greater ".count)) }
        let raw = !stored.isEmpty ? stored : (parsed ?? "")
        guard !raw.isEmpty else { return nil }
        let key = foldKey(raw)
        let inNewYorkState = isNewYorkStateAddress(address)
        if nycNames.contains(key) {
            // Stored "New York City" while the address says Brooklyn: keep Brooklyn as the area.
            if let p = parsed, nycAreas.contains(foldKey(p)), inNewYorkState { return ("New York City", p) }
            return ("New York City", nil)
        }
        if nycAreas.contains(key) && inNewYorkState { return ("New York City", raw) }
        if key.hasSuffix(" county") && inNewYorkState, let p = parsed, nycAreas.contains(foldKey(p)) { return ("New York City", p) }
        return (raw, nil)
    }

    private static func isNewYorkStateAddress(_ address: String?) -> Bool {
        guard let a = address else { return false }
        return a.range(of: #",\s*NY(\s+\d{5})?(,|$)"#, options: .regularExpression) != nil
            || a.range(of: #"\bNY \d{5}\b"#, options: .regularExpression) != nil
    }

    /// Reads the locality out of a formatted address, e.g.
    /// "181 Essex St, New York, NY 10002" -> "New York", "43 Rue Ramey, 75018 Paris, France" -> "Paris",
    /// "2519 R. Notre Dame O, Montréal, QC H3J 1N4, Canada" -> "Montréal".
    static func locality(fromAddress address: String?) -> String? {
        guard let address else { return nil }
        var parts = address.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }
        // Trailing country ("USA", "France", "Japan"): a known country name, or no digits with at least 3 parts.
        if let last = parts.last, countryNames.contains(foldKey(last)) {
            parts.removeLast()
        } else if parts.count >= 3, let last = parts.last, !last.contains(where: \.isNumber) {
            parts.removeLast()
        }
        guard !parts.isEmpty else { return nil }
        // Walk back from the end at most 3 parts until something city-like is left.
        var steps = 0
        while let candidate = parts.popLast(), steps < 3 {
            steps += 1
            let cleaned = stripPostalAndRegion(candidate)
            if isCityLike(cleaned) { return cleaned }
            if parts.isEmpty { break }
        }
        return nil
    }

    /// Drops postal codes (tokens with digits) and 2-3 letter uppercase region codes ("NY", "QC", "CDMX").
    static func stripPostalAndRegion(_ part: String) -> String {
        let tokens = part.split(separator: " ").map(String.init).filter { token in
            if token.contains(where: \.isNumber) { return false }
            let letters = token.filter(\.isLetter)
            if letters.count >= 2 && letters.count <= 4 && letters == letters.uppercased() && token == letters { return false }
            return true
        }
        return tokens.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " -"))
    }

    static let roadSuffixes: Set<String> = ["st", "rd", "ave", "road", "street", "blvd", "dr", "ln", "hwy", "way", "avenue"]

    private static func isCityLike(_ s: String) -> Bool {
        guard s.count >= 3, !s.hasSuffix("."), !s.contains(":"), s.contains(where: \.isLetter) else { return false }
        let key = foldKey(s)
        if countryNames.contains(key) || usStateNames.contains(key) { return false }
        if let lastWord = key.split(separator: " ").last, key.contains(" "), roadSuffixes.contains(String(lastWord)) { return false }
        return true
    }

    /// English country names (from Locale) plus common local spellings, folded.
    static let countryNames: Set<String> = {
        let en = Locale(identifier: "en_US")
        var names = Set(Locale.isoRegionCodes.compactMap { en.localizedString(forRegionCode: $0) }.map(foldKey))
        names.formUnion(["usa", "us", "united states of america", "uk", "england", "scotland", "wales", "mexico",
                         "espana", "deutschland", "italia", "osterreich", "suisse", "schweiz", "svizzera", "danmark",
                         "norge", "korea", "south korea", "republic of korea", "turkiye", "nederland", "belgique",
                         "polska", "ellada", "nihon", "brasil", "peru"])
        return names
    }()

    static let usStateNames: Set<String> = [
        "alabama", "alaska", "arizona", "arkansas", "california", "colorado", "connecticut", "delaware", "florida",
        "georgia", "hawaii", "idaho", "illinois", "indiana", "iowa", "kansas", "kentucky", "louisiana", "maine",
        "maryland", "massachusetts", "michigan", "minnesota", "mississippi", "missouri", "montana", "nebraska",
        "nevada", "new hampshire", "new jersey", "new mexico", "north carolina", "north dakota", "ohio",
        "oklahoma", "oregon", "pennsylvania", "rhode island", "south carolina", "south dakota", "tennessee",
        "texas", "utah", "vermont", "virginia", "west virginia", "wisconsin", "wyoming"
    ]

    /// Lowercased, accent-free key so "Montréal" and "Montreal" group together.
    static func foldKey(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func cityKey(_ name: String) -> String { name.isEmpty ? "_unknown" : foldKey(name) }

    /// Folds tiny cities into a big city within 25 km (e.g. a suburb with 1 place), and gives
    /// places with no city the nearest city within 40 km. Everything else without a city goes to "Other places".
    static func consolidateCities(_ input: [SavedLibraryPlace]) -> [SavedLibraryPlace] {
        var places = input
        func centroids() -> [String: (name: String, lat: Double, lon: Double, count: Int)] {
            var acc: [String: (name: String, lat: Double, lon: Double, count: Int)] = [:]
            for p in places where !p.city.isEmpty {
                guard let lat = p.latitude, let lon = p.longitude else { continue }
                let k = cityKey(p.city)
                let cur = acc[k] ?? (p.city, 0, 0, 0)
                acc[k] = (cur.name, cur.lat + lat, cur.lon + lon, cur.count + 1)
            }
            return acc.mapValues { ($0.name, $0.lat / Double($0.count), $0.lon / Double($0.count), $0.count) }
        }
        var counts: [String: Int] = [:]
        for p in places where !p.city.isEmpty { counts[cityKey(p.city), default: 0] += 1 }
        let centers = centroids()

        // Small city -> nearest bigger city (at least 3x its size and at least 5 places).
        var remap: [String: String] = [:]
        for (key, c) in centers where (counts[key] ?? 0) < smallCityThreshold {
            let small = counts[key] ?? 0
            let target = centers.filter { k, other in
                k != key && (counts[k] ?? 0) >= max(5, small * 3)
                    && distanceMeters(c.lat, c.lon, other.lat, other.lon) <= mergeRadiusMeters
            }.min { distanceMeters(c.lat, c.lon, $0.value.lat, $0.value.lon) < distanceMeters(c.lat, c.lon, $1.value.lat, $1.value.lon) }
            if let target { remap[key] = target.value.name }
        }
        for i in places.indices where !places[i].city.isEmpty {
            if let newCity = remap[cityKey(places[i].city)] {
                if places[i].area == nil { places[i].area = places[i].city }
                places[i].city = newCity
            }
        }

        // Orphans (no city) -> nearest city center within 40 km.
        let finalCenters = centroids()
        for i in places.indices where places[i].city.isEmpty {
            if let lat = places[i].latitude, let lon = places[i].longitude,
               let nearest = finalCenters.values.min(by: { distanceMeters(lat, lon, $0.lat, $0.lon) < distanceMeters(lat, lon, $1.lat, $1.lon) }),
               distanceMeters(lat, lon, nearest.lat, nearest.lon) <= orphanRadiusMeters {
                places[i].city = nearest.name
            } else {
                places[i].city = unknownCityName
            }
        }
        return places
    }

    /// The city for "Dinner in ...": the city the user is in (nearest place within 20 miles), else the biggest city.
    static func homeCity(cities: [SavedCityGroup], places: [SavedLibraryPlace], userLocation: (lat: Double, lon: Double)?) -> SavedCityGroup? {
        let real = cities.filter { $0.name != unknownCityName }
        if userLocation != nil,
           let nearest = places.filter({ $0.distanceMeters != nil && $0.city != unknownCityName }).min(by: { $0.distanceMeters! < $1.distanceMeters! }),
           (nearest.distanceMeters ?? .infinity) <= nearRadiusMeters,
           let group = real.first(where: { $0.key == cityKey(nearest.city) }) {
            return group
        }
        return real.first
    }

    static func shortCityName(_ name: String) -> String {
        name == "New York City" ? "NYC" : name
    }

    /// Newest-added first, then A-Z.
    static func sortPlaces(_ list: [SavedLibraryPlace]) -> [SavedLibraryPlace] {
        list.sorted { a, b in
            switch (a.addedAt, b.addedAt) {
            case let (x?, y?) where x != y: return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }

    // MARK: Type

    static let stayWords: Set<String> = ["lodging", "hotel", "motel", "hostel", "resort", "inn", "bed and breakfast",
                                         "guest house", "campground", "extended stay", "vacation rental"]
    static let sightWords: Set<String> = ["museum", "park", "tourist attraction", "natural feature", "scenic spot", "scenic",
                                          "hiking area", "hiking", "trail", "beach", "art gallery", "gallery", "landmark",
                                          "monument", "historical", "historic", "zoo", "aquarium", "garden", "botanical",
                                          "viewpoint", "observation deck", "lake", "waterfall", "church", "cathedral",
                                          "temple", "shrine", "castle", "palace", "movie theater", "cinema", "theater",
                                          "theatre", "stadium", "arena", "amusement park", "concert hall", "performing arts",
                                          "national park", "state park", "mountain", "island", "bridge", "plaza", "library"]
    static let shopWords: Set<String> = ["store", "shop", "boutique", "market", "supermarket", "grocery", "mall",
                                         "shopping", "florist", "bookstore", "clothing", "outlet", "department store",
                                         "thrift", "vintage", "jewelry", "furniture", "liquor", "convenience"]
    /// Snake-case Google types like "point_of_interest" mean an unordered legacy list (no primary type first).
    static let legacyMarkers: Set<String> = ["point of interest", "establishment"]

    /// Type for one category string, or nil when it says nothing about the venue.
    static func type(ofCategory raw: String) -> SavedPlaceType? {
        let text = TonightCategoryClassifier.tokenText(raw)
        let has: (Set<String>) -> Bool = { words in words.contains { TonightCategoryClassifier.matches(text, $0) } }
        if has(stayWords) { return .stays }
        let kinds = TonightCategoryClassifier.kinds(of: raw)
        if !kinds.isDisjoint(with: [.restaurant, .cuisineRestaurant, .breakfastRestaurant, .lunchFood]) { return .restaurants }
        if !kinds.isDisjoint(with: [.bar, .cocktailOrWineBar, .nightlife]) { return .bars }
        if !kinds.isDisjoint(with: [.coffee, .cafe, .tea, .bakery, .sweets]) { return .coffee }
        if kinds.contains(.lateFood) { return .restaurants }
        if has(sightWords) { return .sights }
        if has(shopWords) { return .shops }
        return nil
    }

    /// Type for a place. A user correction wins; Google's display-name lists put the primary type
    /// first, so the first decisive category wins there; legacy snake-case lists use a fixed priority.
    static func classify(categories: [String], corrected: String?, name: String) -> SavedPlaceType {
        if let corrected, let t = type(ofCategory: corrected) { return t }
        let normalized = categories.map(TonightCategoryClassifier.normalized).filter { !$0.isEmpty }
        let specific = normalized.filter { !TonightCategoryClassifier.genericCategories.contains($0) && !legacyMarkers.contains($0) }
        let types = specific.compactMap(type(ofCategory:))
        if types.isEmpty {
            if normalized.contains("food") || normalized.contains("restaurant") { return .restaurants }
            return type(ofCategory: name) ?? .other
        }
        let isLegacy = categories.contains { $0.contains("_") } || normalized.contains { legacyMarkers.contains($0) }
        if !isLegacy, let first = types.first { return first }
        let priority: [SavedPlaceType] = [.restaurants, .bars, .coffee, .stays, .sights, .shops]
        return priority.first { types.contains($0) } ?? .other
    }

    // MARK: Cuisine

    static let nonCuisineWords: Set<String> = ["fine dining", "family", "takeout", "take out", "fast food", "meal takeaway",
                                               "meal delivery", "restaurant", "restaurants", "brunch", "breakfast", "lunch",
                                               "dinner", "casual", "modern", "new", "upscale", "buffet", "health food", "food"]
    static let cuisineAdjectives: Set<String> = ["authentic", "traditional", "contemporary", "classic", "upscale", "casual"]
    static let cuisineKeywords: [(String, String)] = [
        ("steak house", "Steakhouse"), ("steakhouse", "Steakhouse"), ("pizzeria", "Pizza"), ("pizza", "Pizza"),
        ("sushi", "Sushi"), ("ramen", "Ramen"), ("taqueria", "Mexican"), ("tacos", "Mexican"), ("taco", "Mexican"),
        ("barbecue", "Barbecue"), ("bbq", "Barbecue"), ("izakaya", "Japanese"), ("omakase", "Japanese"),
        ("trattoria", "Italian"), ("osteria", "Italian"), ("bistro", "French"), ("brasserie", "French"),
        ("dim sum", "Chinese"), ("dumpling", "Dumplings"), ("dumplings", "Dumplings"), ("seafood", "Seafood"),
        ("oyster", "Seafood"), ("burger", "Burgers"), ("burgers", "Burgers"), ("hamburger", "Burgers"),
        ("tapas", "Spanish"), ("diner", "Diner"), ("deli", "Deli"), ("sandwich", "Sandwiches"), ("bagel", "Bagels"),
        ("noodle", "Noodles"), ("noodles", "Noodles"), ("poke", "Poke"), ("kebab", "Middle Eastern"),
        ("shawarma", "Middle Eastern"), ("falafel", "Middle Eastern")
    ]

    /// Cuisine from categories like "Japanese restaurant" / "japanese_restaurant" / "Steak house". Nil when unknown.
    static func cuisine(categories: [String], corrected: String?, name: String? = nil) -> String? {
        let pieces = ([corrected].compactMap { $0 } + categories).map(TonightCategoryClassifier.normalized).filter { !$0.isEmpty }
        for piece in pieces {
            if piece.hasSuffix(" restaurant") {
                let rawHead = String(piece.dropLast(" restaurant".count)).trimmingCharacters(in: .whitespaces)
                let head = rawHead.split(separator: " ").drop { cuisineAdjectives.contains(String($0)) }.joined(separator: " ")
                if !head.isEmpty && !nonCuisineWords.contains(head) {
                    if let keyword = keywordCuisine(head) { return keyword }
                    return head.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
                }
            }
            if let keyword = keywordCuisine(piece) { return keyword }
        }
        // Legacy lists often only say "restaurant": try the name ("Joe's Pizza", "Ramen Danbo").
        if let name { return keywordCuisine(TonightCategoryClassifier.normalized(name)) }
        return nil
    }

    private static func keywordCuisine(_ piece: String) -> String? {
        let text = TonightCategoryClassifier.tokenText(piece)
        return cuisineKeywords.first { TonightCategoryClassifier.matches(text, $0.0) }?.1
    }

    // MARK: Dates & distance

    /// Parses Supabase timestamps with or without fractional seconds / time zone (no zone = UTC).
    static func parseTimestamp(_ raw: String?) -> Date? {
        guard var s = raw?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        s = s.replacingOccurrences(of: " ", with: "T")
        let hasZone = s.hasSuffix("Z") || s.range(of: #"[+-]\d{2}:?\d{2}$"#, options: .regularExpression) != nil
        if !hasZone { s += "Z" }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: s) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: s) { return d }
        // More than 3 fractional digits (Postgres gives 6): trim to milliseconds and retry.
        if let dot = s.firstIndex(of: ".") {
            let afterDot = s[s.index(after: dot)...]
            let digits = afterDot.prefix { $0.isNumber }
            let rest = afterDot.dropFirst(digits.count)
            let trimmed = String(s[..<dot]) + "." + String(digits.prefix(3)) + rest
            return withFraction.date(from: trimmed)
        }
        return nil
    }

    /// Great-circle distance in meters.
    static func distanceMeters(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }
}
