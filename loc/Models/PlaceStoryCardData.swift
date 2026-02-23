//
//  PlaceStoryCardData.swift
//  loc
//

import Foundation

/// Pure data model for place story card content.
struct PlaceStoryCardData {
    let placeName: String
    let address: String?
    let backgroundImageURL: URL?
    let placeUniversalLink: URL?
}
