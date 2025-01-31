//
//  UserProfileFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI
import GooglePlaces

struct UserProfileFavoritesView: View {
    var userFavorites: [GMSPlace]
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
                    ForEach(userFavorites, id: \.placeID) { place in
                        VStack {
                            if let image = placeImages[place.placeID!] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 85, height: 85)
                                    .cornerRadius(50)
                                    .clipped()
                            } else {
                                ProgressView()
                                    .frame(width: 85, height: 85)
                            }

                            Text(place.name?.prefix(15) ?? "Unknown")
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
