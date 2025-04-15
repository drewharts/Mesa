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
    @State private var placeColors: [UUID: Color] = [:]

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
                    VStack(spacing: 4) {
                        if let image = viewModel.placeImages[place.id.uuidString ?? ""] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 85, height: 85)
                                .cornerRadius(50)
                                .clipped()
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                        .frame(width: 85, height: 85)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        } else {
                            Circle()
                                .frame(width: 85, height: 85)
                                .foregroundColor(placeColors[place.id] ?? .gray)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1)
                                        .frame(width: 85, height: 85)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                        
                        Text(place.name.prefix(15))
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(width: 85)
                            
                        Text(place.city?.prefix(15) ?? "")
                            .foregroundColor(.black)
                            .font(.caption)
                            .fontWeight(.light)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(width: 85)
                    }
                    .padding(.trailing, 10)
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            for place in places {
                if placeColors[place.id] == nil {
                    placeColors[place.id] = randomColor()
                }
            }
        }
    }
    
    private func randomColor() -> Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
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
                        Text("\(viewModel.placeListMapboxPlaces[list.id]?.count ?? 0) \(viewModel.placeListMapboxPlaces[list.id]?.count == 1 ? "place" : "places")")
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
