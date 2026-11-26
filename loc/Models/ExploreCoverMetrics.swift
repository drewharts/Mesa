//
//  ExploreCoverMetrics.swift
//  loc
//
//  Display sizes of Explore covers, shared by the cards and the image prefetcher so both request
//  identical (size-keyed) cache entries.
//

import UIKit

enum ExploreCoverMetrics {
    /// Popular list card cover (150pt wide, 3:4).
    static let card = CGSize(width: 150, height: 200)
    /// "Browse by city" tile.
    static let city = CGSize(width: 150, height: 96)

    /// Featured hero card cover: full width minus page margins.
    static var hero: CGSize {
        CGSize(width: UIScreen.main.bounds.width - 32, height: 240)
    }
}
