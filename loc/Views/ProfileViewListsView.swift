//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI

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
    let listVM: PlaceListViewModel
    @Binding var showingImagePicker: Bool
    @Binding var selectedList: PlaceListViewModel?

    var body: some View {
        NavigationLink(destination: PlaceListView(placeList: listVM.placeList)) {
            HStack {
                // Display the list’s image if available:
                if let listImage = listVM.getImage() {
                    Image(uiImage: listImage)
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
                    Text(listVM.placeList.name)
                        .font(.body)
                        .foregroundStyle(.black)

                    Text("\(listVM.placeList.places.count) Places")
                        .font(.caption)
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 15)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 30)
        }
        .contextMenu {
            Button {
                selectedList = listVM
                showingImagePicker = true
            } label: {
                Label("Add Photo", systemImage: "photo")
            }
        }
    }
}

struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel

    // State for handling image picker
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?

    // State to remember which list was selected for adding a photo
    @State private var selectedList: PlaceListViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ListHeaderView()

            if !profile.placeListViewModels.isEmpty {
                ScrollView {
                    ForEach(profile.placeListViewModels) { listVM in
                        PlaceListCellView(
                            listVM: listVM,
                            showingImagePicker: $showingImagePicker,
                            selectedList: $selectedList
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
            ImagePicker(image: $inputImage)
        }
        .onChange(of: inputImage) {
            selectedList?.addPhotoToList(image: inputImage!)
            
            inputImage = nil
            selectedList = nil
        }
    }
}
