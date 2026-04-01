//
//  ListStoryCardData.swift
//  loc
//
//  Created by Claude on 1/30/25.
//

import Foundation

/// Pure data model for list story card content.
struct ListStoryCardData {
    let listName: String
    let placeCount: Int
    let ownerName: String
    let ownerPhotoURL: URL?
    let city: String?
    let backgroundImageURL: URL?
    let listUniversalLink: URL?
}
