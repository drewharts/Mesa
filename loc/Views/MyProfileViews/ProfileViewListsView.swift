//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI
import MapboxSearch

struct ListHeaderView: View {
    var body: some View {
        Text("LISTS")
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .foregroundStyle(.black)
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
                } else {
                    Rectangle()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.gray)
                        .cornerRadius(4)
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
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel // Add this
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let places: [DetailPlace] // Keep as [DetailPlace]
    @State private var placeColors: [UUID: Color] = [:]
    
    var body: some View {
        HStack {
            ForEach(places, id: \.id) { place in
                Button(action: {
                    selectedPlaceVM.selectedPlace = place
                    selectedPlaceVM.isDetailSheetPresented = true
                    presentationMode.wrappedValue.dismiss()
                }) {
                    VStack {
                        if let image = detailPlaceViewModel.placeImages[place.id.uuidString] { // Use DetailPlaceViewModel
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 85, height: 85)
                                .cornerRadius(50)
                                .clipped()
                        } else {
                            Circle()
                                .frame(width: 85, height: 85)
                                .foregroundColor(colorForPlace(place))
                                .onAppear {
                                    detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                                }
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

struct ProfileListDescription: View {
    @State var list: PlaceList
    
    var body: some View {
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
}


struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel // Add this
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ListHeaderView()

            if !profile.userLists.isEmpty {
                ForEach(profile.userLists, id: \.id) { list in // Explicitly use id
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
