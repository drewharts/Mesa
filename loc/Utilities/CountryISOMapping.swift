//
//  CountryISOMapping.swift
//  loc
//
//  Maps database country names to ISO 3166-1 alpha-2 codes for GeoJSON matching.
//

import Foundation

enum CountryISOMapping {
    /// Maps known database country names to their ISO 3166-1 alpha-2 codes.
    static let nameToISO: [String: String] = [
        "Australia": "AU",
        "Austria": "AT",
        "Brazil": "BR",
        "Canada": "CA",
        "Colombia": "CO",
        "Cyprus": "CY",
        "Denmark": "DK",
        "France": "FR",
        "Germany": "DE",
        "Greece": "GR",
        "Iceland": "IS",
        "India": "IN",
        "Indonesia": "ID",
        "Ireland": "IE",
        "Italy": "IT",
        "Japan": "JP",
        "Lebanon": "LB",
        "Mexico": "MX",
        "Morocco": "MA",
        "Netherlands": "NL",
        "New Zealand": "NZ",
        "Norway": "NO",
        "Peru": "PE",
        "Portugal": "PT",
        "Puerto Rico": "PR",
        "South Korea": "KR",
        "Spain": "ES",
        "Sweden": "SE",
        "Switzerland": "CH",
        "Thailand": "TH",
        "Turkey": "TR",
        "UK": "GB",
        "US": "US",
        "Vietnam": "VN"
    ]

    /// Converts an array of database country names to a set of ISO alpha-2 codes.
    static func isoCodesFromNames(_ names: [String]) -> Set<String> {
        Set(names.compactMap { nameToISO[$0] })
    }
}
