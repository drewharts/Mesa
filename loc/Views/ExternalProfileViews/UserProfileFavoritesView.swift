//
//  UserProfileFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI
import GooglePlaces
import MapboxSearch

struct UserProfileFavoritesView: View {
    var userFavorites: [DetailPlace]
    var placeImages: [String: UIImage]
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode // For dismissing the sheet


    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("FAVORITES")
                .font(.headline)
                .padding(.leading, 20)
                .foregroundStyle(.black)


            if !userFavorites.isEmpty {
                HStack {
                    ForEach(userFavorites, id: \.id) { place in
                        VStack {
                            if let image = placeImages[place.id.uuidString] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 85, height: 85)
                                    .cornerRadius(50)
                                    .clipped()
                            } else {
                                Circle()
                                    .frame(width: 85, height: 85)
                                    .foregroundColor(.gray)
                            }

                            Text(place.name.prefix(16) ?? "Unknown")
                                .foregroundColor(.black)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 85)
                        }
                        .padding(.trailing, 10)
                        .onTapGesture {
                            selectedPlaceVM.selectedPlace = place
                            selectedPlaceVM.isDetailSheetPresented = true
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    Spacer() // Pushes everything to the left
                }
                .padding(.horizontal, 20)
            } else {
                Text("No favorites available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
    }
}
