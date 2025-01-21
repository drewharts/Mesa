//
//  CurrentFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/20/25.
//

import SwiftUI
import GooglePlaces

struct CurrentFavoritesView: View {
    @ObservedObject var profileViewModel: ProfileViewModel

    var body: some View {
        if !profileViewModel.favoritePlaces.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(profileViewModel.favoritePlaces) { place in
                        // Blue box with the restaurant name and "X" icon
                        HStack {
                            // Restaurant name
                            Text(place.name)
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.leading, 8) // Add leading padding for text
                            
                            Spacer()
                            
                            // "X" icon
                            Button(action: {
                                // Remove the selected favorite
                                profileViewModel.removeFavoritePlace(place: place)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.headline) // Match font size for better proportions
                            }
                            .padding(.trailing, 8) // Add trailing padding for the icon
                        }
                        .padding(.vertical, 8) // Vertical padding inside the blue box
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
