//
//  AddFavoritesCurrentFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct AddFavoritesCurrentFavoritesView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
    var body: some View {
        if !profile.userFavorites.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(profile.userFavorites, id: \.self) { place in
                        // Blue box with the restaurant name and "X" icon
                        HStack {
                            // Restaurant name
                            Text(places.places[place]?.name ?? "")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.leading, 8) // Add leading padding for text
                            
                            Spacer()
                            
                            // "X" icon
                            Button(action: {
                                // Remove the selected favorite
                                profile.removeFavoritePlace(place: places.places[place]!)
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
