//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI
import MapboxSearch

// MARK: - ListDeletionRowView
struct ListDeletionRowView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    let list: PlaceList
    var onDelete: (PlaceList) -> Void
    @State private var backgroundColor: Color = Color(.systemGray5)
    
    var body: some View {
        Button(action: {
            onDelete(list)
        }) {
            HStack {
                // Display list image, place image, or colored rectangle
                Group {
                    if let image = profile.listImages[list.id] {
                        // List has a custom image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let placeIds = profile.placeListMBPlaces[list.id], 
                              !placeIds.isEmpty, 
                              let firstPlaceId = placeIds.first,
                              let image = detailPlaceViewModel.placeImages[firstPlaceId] {
                        // Use the first place's image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // No image available, use a colored rectangle
                        Rectangle()
                            .foregroundColor(backgroundColor)
                            .onAppear {
                                backgroundColor = Color(
                                    red: Double.random(in: 0.5...0.9),
                                    green: Double.random(in: 0.5...0.9),
                                    blue: Double.random(in: 0.5...0.9)
                                )
                            }
                    }
                }
                .frame(width: 75, height: 75)
                .clipped()
                .cornerRadius(4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.body)
                        .foregroundStyle(Color.primary.opacity(1.0))

                    Text("\(profile.placeListMBPlaces[list.id]?.count ?? 0) Places")
                        .font(.caption)
                        .foregroundStyle(Color.secondary.opacity(1.0))
                }
                .padding(.horizontal, 15)
                
                Spacer()
                
                Image(systemName: "trash")
                    .foregroundColor(.gray)
                    .padding(.trailing, 10)
            }
            .padding(.top, 20)
            .padding(.horizontal, 15)
        }
    }
}

// MARK: - ListDeletionSheet
struct ListDeletionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                
                Text("Delete List")
                    .font(.headline)
                    .padding(.leading, 20)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .imageScale(.small)
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Circle().fill(.white))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            ScrollView {
                if !profile.userLists.isEmpty {
                    ForEach(profile.userLists) { list in
                        ListDeletionRowView(list: list, onDelete: { list in
                            profile.removePlaceList(placeList: list)
                            if profile.userLists.isEmpty {
                                isPresented = false
                            }
                        })
                    }
                } else {
                    Text("No lists available")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.vertical, 30)
                }
            }
            
            Spacer()
        }
        .cornerRadius(20)
        .padding()
    }
}

struct ListHeaderView: View {
    var onAddList: () -> Void
    var onDeleteList: () -> Void
    
    var body: some View {
        HStack {
            Text("LISTS")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.black)
            
            Button(action: onDeleteList) {
                Image(systemName: "minus.circle")
                    .foregroundColor(.gray)
            }
            
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
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    @State private var showingDeleteListSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ListHeaderView(onAddList: {
                showingNewListSheet = true
            }, onDeleteList: {
                showingDeleteListSheet = true
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
        .sheet(isPresented: $showingDeleteListSheet) {
            ListDeletionSheet(isPresented: $showingDeleteListSheet)
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
