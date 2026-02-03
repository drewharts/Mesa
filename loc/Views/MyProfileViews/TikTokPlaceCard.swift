//
//  TikTokPlaceCard.swift
//  loc
//
//  Wrapper for ProfileGridPlaceCard with TikTok-first image priority.
//  Kept for backward compatibility.
//

import SwiftUI

/// Card for displaying TikTok places in profile grids.
/// Uses ProfileGridPlaceCard with TikTok thumbnail prioritization.
struct TikTokPlaceCard: View {
    let place: LightweightPlace

    var body: some View {
        ProfileGridPlaceCard(place: place, preferTikTokThumbnail: true)
    }
}
