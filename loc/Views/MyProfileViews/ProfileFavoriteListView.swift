//
//  ProfileFavoriteListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/22/24.
//

import SwiftUI

struct ProfileFavoriteListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var places: DetailPlaceViewModel
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    .foregroundStyle(.black)
                    .padding(.top, -10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)

            // 2) Favorite places or placeholders
            HStack(spacing: 10) {
                // Display existing favorites
                ForEach(profile.userFavorites, id: \.self) { place in
                    let detailPlace = places.places[place]
                    VStack {
                        ZStack {
                            if let image = places.placeImages[place] {
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
                        Text(detailPlace?.name.prefix(15) ?? "Unknown")
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(width: 85)
                        Text(detailPlace?.city?.prefix(15) ?? "")
                            .foregroundColor(.black)
                            .font(.caption)
                            .fontWeight(.light)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(width: 85)
                    }
                    .onTapGesture {
                        selectedPlaceVM.selectedPlace = detailPlace
                        selectedPlaceVM.isDetailSheetPresented = true
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                // Add placeholder circles if fewer than 4 favorites
                if profile.userFavorites.count < 4 {
                    ForEach(profile.userFavorites.count..<4, id: \.self) { _ in
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 85, height: 85)
                                Image(systemName: "plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }
                            .padding(.bottom, 20)
                        }
                        .onTapGesture {
                            showSearch = true
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center) // Center the content
            .padding(.horizontal, 20)

            Divider()
                .padding(.horizontal, 20)
        }
        // Present AddFavoritesView in a sheet
        .sheet(isPresented: $showSearch) {
            AddFavoritesView()
        }
    }
}
