//
//  TikTokPlaceFlaggingView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

/// Displays a tappable row that allows users to correct place detection for TikTok videos.
struct TikTokPlaceFlaggingView: View {
    let place: DetailPlace
    let externalPlaceId: String?
    @EnvironmentObject var profile: ProfileViewModel

    @State private var showingPlaceCorrectionSheet = false

    /// Callback when user changes the place association - parent should navigate to new place.
    var onPlaceChanged: ((DetailPlace) -> Void)?

    var body: some View {
        Button(action: {
            showingPlaceCorrectionSheet = true
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16, weight: .medium))

                Text("Help Improve Detection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPlaceCorrectionSheet) {
            TikTokPlaceCorrectionSheet(
                mode: .correction(externalPlaceId: externalPlaceId ?? "", currentPlaceName: place.name),
                onPlaceChanged: { newPlace in
                    profile.recordPlaceCorrectionFlag(for: place.id.uuidString, newPlaceId: newPlace.id.uuidString)
                    onPlaceChanged?(newPlace)
                }
            )
            .environmentObject(profile)
        }
    }
}
