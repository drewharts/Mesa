//  PlaceSelectionView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI

struct PlaceSelectionView: View {
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("📍 Select a Place")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Text("Found \(photoImportVM.nearbyPlaces.count) places near your photo")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Places List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(photoImportVM.nearbyPlaces) { place in
                            PlaceSelectionRowView(
                                place: place,
                                onSelect: {
                                    photoImportVM.selectPlace(place)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Create New Place Button
                Button(action: {
                    // TODO: Handle create new place
                    print("Create new place tapped")
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Place")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
} 