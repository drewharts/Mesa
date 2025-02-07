//
//  ProfileFavoriteListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/22/24.
//

import SwiftUI

struct ProfileFavoriteListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode // For dismissing the sheet
    @State private var showSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 1) "FAVORITES" button
            Button {
                showSearch = true
            } label: {
                Text("FAVORITES")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .foregroundStyle(.black)
                    .padding(.top, -10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)

            // 2) Favorite places
            if !profile.userFavorites.isEmpty {
                HStack {
                    ForEach(profile.userFavorites, id: \.id) { place in
                        VStack {
                            ZStack {
                                if let image = profile.placeImages[place.id]{
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 85, height: 85)
                                        .cornerRadius(50)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: 85, height: 85)
                                        .cornerRadius(50)
                                }
                            }
                            Text(place.name.prefix(15) ?? "Unknown")
                                .foregroundColor(.black)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 85)
                        }
                        .padding(.trailing, 10)
                        .onTapGesture {
                            // Update the selected place in the view model and dismiss
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

            Divider()
                .padding(.top, 15)
                .padding(.horizontal, 20)
        }
        // Present AddFavoritesView in a sheet
        .sheet(isPresented: $showSearch) {
//            AddFavoritesView()
        }
    }
}
