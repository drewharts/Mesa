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


            if !profile.placeListViewModels.isEmpty {
                ScrollView {
                    ForEach(profile.placeListViewModels) { listVM in
                        NavigationLink(destination: PlaceListView(placeList: listVM.placeList)) {
                            HStack {
                                // Display the list’s image if available:
                                if let decodedImage = decodedUIImage(from: listVM.placeList.image) {
                                    Image(uiImage: decodedImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(4)
                                } else {
                                    // Fallback placeholder
                                    Rectangle()
                                        .frame(width: 100, height: 100)
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
                                Spacer()
                            }
                            .padding()
                            .padding(.horizontal)
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
        
        // Example: Convert the UIImage to Base64 and store it in the model
        if let imageData = uiImage.jpegData(compressionQuality: 0.8) {
            let base64 = imageData.base64EncodedString()
            
            // Update the PlaceList's image property
            selectedList.placeList.image = base64
            
            // Optionally, persist this to Firestore or your backend here
            // e.g. profile.firestoreService.updateListImage(...)
        }
        
        // Reset states
        self.inputImage = nil
        self.selectedList = nil
    }
    
    /// Helper to decode a Base64 string into a UIImage
    private func decodedUIImage(from base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64),
              let uiImage = UIImage(data: data) else {
            return nil
        }
        return uiImage
    }
}

