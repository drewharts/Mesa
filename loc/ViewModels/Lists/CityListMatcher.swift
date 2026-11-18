//
//  CityListMatcher.swift
//  loc
//
//  Pure rules for "saves go to a city list": which list name a place belongs under, and which of
//  the user's existing lists already is that city. Unit tested in CityListMatcherTests.
//
//  Matching rules:
//  1. A list matches when its name, folded (case, accents, punctuation), is the city's name or one of
//     its aliases. "new york city", "NYC", "New York" and the five boroughs are one city.
//     Other aliases: SF/San Fran, LA, DC, Philly, Vegas, NOLA, CDMX.
//  2. An exact name match beats an alias match ("New York City" beats "Brooklyn"); among several,
//     the list with the most places wins, then A-Z, then list id, so the pick is deterministic.
//  3. Only lists the user owns can receive a save: lists shared with the user and paid lists are skipped.
//  4. List names that merely contain the city ("NYC Restaurants", "Paris trip") never match.
//

import Foundation

enum CityListMatcher {
    /// Name of the list used when a place's city can't be determined.
    static let fallbackListName = "Saved"

    /// Canonical name for the five boroughs and NYC spellings.
    static let nycName = "New York City"

    /// Boroughs a user may have named a list after. Narrower than the neighborhood set the builder
    /// uses for places, because a list called "Jamaica" or "Corona" is not about New York.
    private static let nycBoroughKeys: Set<String> = ["manhattan", "brooklyn", "queens", "bronx", "the bronx", "staten island"]

    /// Folded nickname -> folded canonical city.
    private static let aliasKeys: [String: String] = [
        "sf": "san francisco", "san fran": "san francisco",
        "la": "los angeles", "l a": "los angeles",
        "dc": "washington dc", "washington d c": "washington dc",
        "philly": "philadelphia", "vegas": "las vegas", "nola": "new orleans",
        "cdmx": "mexico city", "ciudad de mexico": "mexico city"
    ]

    /// The display city for a place: the stored city or address locality, or nil when neither says.
    static func cityName(storedCity: String?, address: String?) -> String? {
        SavedLibraryBuilder.city(storedCity: storedCity, address: address)?.city
    }

    /// Identity of a city or list name: equal keys mean "the same city" (NYC == New York). Borough names
    /// only count as NYC for list names; a place's borough is already folded into NYC by `cityName`.
    static func cityKey(_ name: String, includeBoroughs: Bool = false) -> String {
        let key = SavedLibraryBuilder.foldKey(name)
        if SavedLibraryBuilder.nycNames.contains(key) || (includeBoroughs && nycBoroughKeys.contains(key)) {
            return SavedLibraryBuilder.foldKey(nycName)
        }
        return aliasKeys[key] ?? key
    }

    /// The user's list that already stands for `cityName`, or nil when one has to be created.
    static func match(cityName: String, in lists: [LightweightPlaceList]) -> LightweightPlaceList? {
        let wanted = cityKey(cityName)
        let exactKey = SavedLibraryBuilder.foldKey(cityName)
        let candidates = lists.filter {
            isEligibleTarget($0)
                && (cityKey($0.name, includeBoroughs: true) == wanted || SavedLibraryBuilder.foldKey($0.name) == exactKey)
        }
        return candidates.min { a, b in
            let aExact = SavedLibraryBuilder.foldKey(a.name) == exactKey
            let bExact = SavedLibraryBuilder.foldKey(b.name) == exactKey
            if aExact != bExact { return aExact }
            if a.place_count != b.place_count { return a.place_count > b.place_count }
            let byName = a.name.localizedCaseInsensitiveCompare(b.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return a.list_id < b.list_id
        }
    }

    /// Whether a save may land in this list: owned by the user and not a paid list.
    static func isEligibleTarget(_ list: LightweightPlaceList) -> Bool {
        !list.isSharedWithMe && !list.isPaid
    }
}
