//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI
import MapboxSearch

// MARK: - ListHeaderView
struct ListHeaderView: View {
    var onAddList: () -> Void
    
    var body: some View {
        HStack {
            Text("LISTS")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.black)
            
            Button(action: onAddList) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.gray)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.vertical, -25)
        .padding(.horizontal, 10)
    }
}

struct PlaceListCellView: View {
    let list: PlaceList
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel // Add this
    @Binding var showingImagePicker: Bool
    
    var onPlaceSelected: ((SearchResult) -> Void)?

    var body: some View {
        NavigationLink(destination: PlaceListView(places: getPlacesForList())) {
            HStack {
                if let image = profile.listImages[list.id] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .clipped()
                        .cornerRadius(4)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 90, height: 90)
                                .cornerRadius(4)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                } else {
                    Rectangle()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 90, height: 90)
                                .cornerRadius(4)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.body)
                        .foregroundStyle(.black)

                    Text("\(profile.placeListMBPlaces[list.id]?.count ?? 0) Places")
                        .font(.caption)
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 15)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 30)
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button {
                showingImagePicker = true
            } label: {
                Label("Add Photo", systemImage: "photo")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                profile.removePlaceList(placeList: list)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    // Helper to convert place IDs to DetailPlace objects
    private func getPlacesForList() -> [DetailPlace] {
        let placeIds = profile.placeListMBPlaces[list.id] ?? []
        return placeIds.compactMap { detailPlaceViewModel.places[$0] }
    }
}

struct MyProfileHorizontalListPlaces: View {
    @EnvironmentObject var viewModel: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let places: [DetailPlace]
    @State private var placeColors: [UUID: Color] = [:]
    
    var body: some View {
        HStack {
            ForEach(places, id: \.id) { place in
                Button(action: {
                    selectedPlaceVM.selectedPlace = place
                    selectedPlaceVM.isDetailSheetPresented = true
                    presentationMode.wrappedValue.dismiss()
                }) {
                    VStack(spacing: 4) {
                        if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
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
                                .foregroundColor(colorForPlace(place))
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
    
    private func colorForPlace(_ place: DetailPlace) -> Color {
        placeColors[place.id] ?? .gray
    }
}

struct ListPlacesPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    let list: PlaceList
    @State private var showingDeleteConfirmation = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Reduced width to create more space between cards
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35 // Increased spacing from edges
    private let cardHeight: CGFloat = 180 // Slightly reduced height
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Text(list.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
                
                // Empty view with same width as trash button for perfect centering
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer()
                .frame(height: 20) // Add extra space between title and content
            
            if let placeIds = profile.placeListMBPlaces[list.id] {
                let places = placeIds.compactMap { detailPlaceViewModel.places[$0] }
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
                                            if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: cardWidth, height: cardHeight)
                                                    .clipped()
                                            } else {
                                                Rectangle()
                                                    .foregroundColor(.gray)
                                                    .frame(width: cardWidth, height: cardHeight)
                                            }
                                            
                                            // Gradient overlay that extends from the bottom
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
                                            
                                            // Text overlay at the bottom
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(place.name)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                if let city = place.city {
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
                                .contextMenu {
                                    Button(role: .destructive) {
                                        profile.removePlaceFromList(place: place, list: list)
                                    } label: {
                                        Label("Remove from list", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20) // Increased horizontal padding
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
        .alert("Delete List", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                profile.removePlaceList(placeList: list)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this list? This action cannot be undone.")
        }
    }
}

struct ProfileListDescription: View {
    @State var list: PlaceList
    @State private var showingPlacesPopup = false
    
    var body: some View {
        Button(action: {
            showingPlacesPopup = true
        }) {
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
        }
        .sheet(isPresented: $showingPlacesPopup) {
            ListPlacesPopupView(list: list)
        }
    }
}

struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ListHeaderView(onAddList: {
                showingNewListSheet = true
            })

            if !profile.userLists.isEmpty {
                ForEach(profile.userLists, id: \.id) { list in
                    VStack(alignment: .leading) {
                        ProfileListDescription(list: list)
                        
                        if let placeIds = profile.placeListMBPlaces[list.id] {
                            ScrollView(.horizontal, showsIndicators: false) {
                                MyProfileHorizontalListPlaces(places: placeIds.compactMap { detailPlaceViewModel.places[$0] })
                            }
                        } else {
                            Text("Loading places...")
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                        }
                    }
                }
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .sheet(isPresented: $showingNewListSheet) {
            NewListView(isPresented: $showingNewListSheet, onSave: { listName in
                profile.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
            })
        }
        .onChange(of: inputImage) { _ in
            guard let newImage = inputImage.first, let selectedList = selectedList else { return }
            selectedList.addPhotoToList(image: newImage)
            profile.listImages[selectedList.placeList.id] = newImage
            inputImage = []
            self.selectedList = nil
        }
        .onChange(of: selectedPlaceVM.isDetailSheetPresented) { newValue in
            if newValue == true {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
