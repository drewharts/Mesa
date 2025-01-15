//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI

struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    
    // State for handling image picker
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    
    // State to remember which list was selected for adding a photo
    @State private var selectedList: PlaceListViewModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text("LISTS")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .foregroundStyle(.black)
                .padding(.vertical, -25)
                .padding(.horizontal, 15)
            
            
            if !profile.placeListViewModels.isEmpty {
                ScrollView {
                    ForEach(profile.placeListViewModels) { listVM in
                        NavigationLink(destination: PlaceListView(placeList: listVM.placeList)) {
                            HStack {
                                // Display the list’s image if available:
                                if !listVM.placeList.image.isEmpty {
                                    AsyncImage(url: URL(string: listVM.placeList.image)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 90, height: 90)
                                                .clipped()
                                                .cornerRadius(4)
                                        case .failure(_):
                                            // Placeholder in case of error
                                            Rectangle()
                                                .frame(width: 90, height: 90)
                                                .foregroundColor(.gray)
                                                .cornerRadius(4)
                                        case .empty:
                                            // Placeholder while loading
                                            ProgressView()
                                                .frame(width: 90, height: 90)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
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
                            .padding(.horizontal,35)
                        }
                        // Context menu (long-press) to add a photo
                        .contextMenu {
                            Button {
                                // Show the image picker + store the selected list
                                selectedList = listVM
                                showingImagePicker = true
                            } label: {
                                Label("Add Photo", systemImage: "photo")
                            }
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
        
        // Present the image picker as a sheet
        .sheet(isPresented: $showingImagePicker, onDismiss: handleImagePicked) {
            ImagePicker(image: $inputImage)
        }
    }
    
    /// Called after the user finishes picking an image
    private func handleImagePicked() {
        guard let uiImage = inputImage,
              let selectedList = selectedList else {
            return
        }
        
        // Call the addPhotoToList function in the selected PlaceListViewModel
        selectedList.addPhotoToList(image: uiImage)
        
        // Reset states
        self.inputImage = nil
        self.selectedList = nil
    }
}


