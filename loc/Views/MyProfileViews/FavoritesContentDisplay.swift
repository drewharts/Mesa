//
//  FavoritesContentDisplay.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct FavoritesContentDisplay: View {
    @EnvironmentObject var profile: ProfileViewModel
    var prediction: MesaPlaceSuggestion
    @State private var lastTappedPlaceID: String?

    var body: some View {
        ZStack {
            // Existing HStack for content display
            HStack {
                Text(prediction.name)
                    .foregroundColor(.primary)
                Text((prediction.address) ?? "")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 6)
            .background(
                prediction.id == lastTappedPlaceID
                    ? Color.blue.opacity(0.2)
                    : Color.clear
            )

            // Transparent rectangle to capture taps over the entire row
            Rectangle()
                .fill(Color.clear) // Makes the rectangle transparent
                .contentShape(Rectangle()) // Makes the entire rectangle tappable, not just the area with content
                .onTapGesture {
                    // 1) Append to favorites (directly via ProfileViewModel)
                    profile.addFavoriteFromSuggestion(place: prediction)
                    // 2) Highlight this row
                    lastTappedPlaceID = prediction.id

                    // 3) Clear highlight after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            lastTappedPlaceID = nil
                        }
                    }
                }
        }
    }
}
