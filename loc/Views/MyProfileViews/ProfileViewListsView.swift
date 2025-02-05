//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI
import GooglePlaces

struct ListHeaderView: View {
    var body: some View {
        Text("LISTS")
            .font(.headline)
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
    @Binding var showingImagePicker: Bool
    
    var onPlaceSelected: ((GMSPlace) -> Void)?


    var body: some View {
        NavigationLink(destination: PlaceListView(places: profile.placeListGMSPlaces[list.id] ?? [])) {
            HStack {
                if let image = profile.listImages[list.id] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .clipped()
                        .cornerRadius(4)

                } else {
                    // Fallback placeholder
                    Rectangle()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.body)
                        .foregroundStyle(.black)

                    Text("\(profile.placeListGMSPlaces[list.id]?.count ?? 0) Places")
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
    }
}


struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) private var presentationMode


    // State for handling image picker
    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []

    // State to remember which list was selected for adding a photo
    @State private var selectedList: PlaceListViewModel?
    

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ListHeaderView()

            if !profile.userLists.isEmpty {
                ScrollView {
                    ForEach(profile.userLists) { list in
                        PlaceListCellView(
                            list: list,
                            showingImagePicker: $showingImagePicker
                        )
                    }
                }
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)

        // Present the image picker as a sheet
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .onChange(of: inputImage) {
            guard let newImage = inputImage.first, let selectedList = selectedList else { return }
            selectedList.addPhotoToList(image: newImage)
            profile.listImages[selectedList.placeList.id] = newImage  // Replace or set the image

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
