//
//  UserProfileListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileListViewJustListsPlaces: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var viewModel: UserProfileViewModel
    var places: [DetailPlace]
    var body: some View {
        HStack {
            ForEach(places, id: \.id) { place in
                Button(action: {
                    selectedPlaceVM.selectedPlace = place
                    selectedPlaceVM.isDetailSheetPresented = true
                    presentationMode.wrappedValue.dismiss()
                }) {
                    VStack {
                        if let image = viewModel.placeImages[place.id.uuidString ?? ""] {
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
                        
                        Text(place.name ?? "Unknown")
                            .font(.footnote)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(width: 85)
                    }
                    .padding(.trailing, 10)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct UserProfileListViewJustLists: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var placeLists: [PlaceList]

    var body: some View {
        ScrollView {
            ForEach(placeLists) { list in
                VStack(alignment: .leading) {
                    HStack {
                        Text(list.name)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .padding(.leading, 20)
                        Text("\(list.places.count) \(list.places.count == 1 ? "place" : "places")")
                            .font(.caption)
                            .foregroundStyle(.black)
                    }

                    if let places = viewModel.placeListMapboxPlaces[list.id] {
                        ScrollView(.horizontal, showsIndicators: false) {
                            UserProfileListViewJustListsPlaces(viewModel: viewModel, places: places)
                        }
                    } else {
                        Text("Loading places...")
                            .foregroundColor(.gray)
                            .padding(.leading, 20)
                    }
                }
            }
        }
    }
}

struct UserProfileListsView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var placeLists: [PlaceList]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("LISTS")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20) // Match Favorites
                .foregroundStyle(.black)

            if placeLists.isEmpty {
                Text("No lists available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            } else {
                UserProfileListViewJustLists(viewModel: viewModel, placeLists: placeLists)
            }
        }
    }
}
