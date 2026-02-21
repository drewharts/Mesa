//
//  ExternalPlaceCard.swift
//  loc
//
//  Wrapper for ProfileGridPlaceCard with external video-first image priority.
//  Kept for backward compatibility.
//

import SwiftUI

/// Card for displaying external video places in profile grids.
/// Uses ProfileGridPlaceCard with external video thumbnail prioritization.
struct ExternalPlaceCard: View {
    let place: LightweightPlace

    var body: some View {
        ProfileGridPlaceCard(place: place, preferExternalThumbnail: true)
    }
}
