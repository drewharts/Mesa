//
//  UserProfileListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileListPlacesPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    let list: PlaceList
    @ObservedObject var viewModel: UserProfileViewModel
    @Binding var placeColors: [UUID: Color]
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                
                Text(list.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer()
                .frame(height: 20)
            
            if let places = viewModel.placeListMapboxPlaces[list.id] {
                if !places.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(places, id: \.id) { place in
                                Button(action: {
                                    selectedPlaceVM.selectedPlace = place
                                    selectedPlaceVM.isDetailSheetPresented = true
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ZStack(alignment: .bottom) {
                                            if let image = viewModel.placeImages[place.id.uuidString] {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: cardWidth, height: cardHeight)
                                                    .clipped()
                                            } else {
                                                Rectangle()
                                                    .foregroundColor(placeColors[place.id] ?? .gray)
                                                    .frame(width: cardWidth, height: cardHeight)
                                            }
                                            
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.black.opacity(0.0),
                                                    Color.black.opacity(0.1),
                                                    Color.black.opacity(0.2),
                                                    Color.black.opacity(1.0)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            .frame(width: cardWidth, height: cardHeight)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(place.name)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                if let type = detailPlaceViewModel.placeTypes[place.id.uuidString] {
                                                    Text(type)
                                                        .font(.subheadline)
                                                        .foregroundColor(.white.opacity(0.7))
                                                        .lineLimit(1)
                                                } else if let city = place.city {
                                                    Text(city)
                                                        .font(.subheadline)
                                                        .foregroundColor(.white.opacity(0.7))
                                                        .lineLimit(1)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.bottom, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .frame(width: cardWidth, height: cardHeight)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                } else {
                    Text("No places in this list")
                        .foregroundColor(.gray)
                        .padding(.vertical, 30)
                }
            } else {
                Text("Loading places...")
                    .foregroundColor(.gray)
                    .padding(.vertical, 30)
            }
        }
        .cornerRadius(20)
        .padding()
    }
}

struct UserProfileListRow: View {
    @ObservedObject var viewModel: UserProfileViewModel
    let list: PlaceList
    @Binding var placeColors: [UUID: Color]
    @Binding var selectedList: PlaceList?
    @Binding var showingPlacesPopup: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                selectedList = list
                showingPlacesPopup = true
            }) {
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
            }

            if let places = viewModel.placeListMapboxPlaces[list.id] {
                ScrollView(.horizontal, showsIndicators: false) {
                    UserProfileListViewJustListsPlaces(placeColors: $placeColors, viewModel: viewModel, places: places)
                }
            } else {
                Text("Loading places...")
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }
        }
    }
}

struct UserProfileListViewJustLists: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var placeLists: [PlaceList]
    @State private var placeColors: [UUID: Color] = [:]
    @State private var selectedList: PlaceList?
    @State private var showingPlacesPopup = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(placeLists.sorted(by: { $0.sortOrder < $1.sortOrder })) { list in
                    UserProfileListRow(
                        viewModel: viewModel,
                        list: list,
                        placeColors: $placeColors,
                        selectedList: $selectedList,
                        showingPlacesPopup: $showingPlacesPopup
                    )
                }
            }
        }
        .sheet(isPresented: $showingPlacesPopup) {
            if let list = selectedList {
                UserProfileListPlacesPopupView(list: list, viewModel: viewModel, placeColors: $placeColors)
            }
        }
    }
}

struct UserProfileListViewJustListsPlaces: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var placeColors: [UUID: Color]

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
                        if let image = viewModel.placeImages[place.id.uuidString] {
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
                        
                        if let type = detailPlaceViewModel.placeTypes[place.id.uuidString] {
                            Text(type.prefix(15))
                                .foregroundColor(.black)
                                .font(.caption)
                                .fontWeight(.light)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 85)
                        } else if let city = place.city {
                            Text(city.prefix(15))
                                .foregroundColor(.black)
                                .font(.caption)
                                .fontWeight(.light)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .frame(width: 85)
                        }
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
