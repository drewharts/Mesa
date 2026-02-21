//
//  ReviewsPlaceCard.swift
//  loc
//
//  Wrapper for ProfileGridPlaceCard with review photo priority.
//  Kept for backward compatibility.
//

import SwiftUI

/// Card for displaying reviewed places in profile grids.
/// Uses ProfileGridPlaceCard with review photo prioritization.
struct ReviewsPlaceCard: View {
    let place: LightweightPlace

    var body: some View {
        ProfileGridPlaceCard(place: place, preferExternalThumbnail: false)
    }
}
