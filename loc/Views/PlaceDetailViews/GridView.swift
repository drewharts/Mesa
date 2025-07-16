//
//  GridView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//

import SwiftUI

struct GridView: View {
    let images: [UIImage]
    let onImageTapped: (Int) -> Void

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    // For a 3-column grid
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(images.indices, id: \.self) { index in
                GeometryReader { geo in
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                        .cornerRadius(4)
                }
                .aspectRatio(1, contentMode: .fill)
                .onTapGesture {
                    onImageTapped(index)
                }
                .onAppear {
                    // If this is the last image, load more
                    if index == images.count - 1 && !selectedPlaceVM.allPhotosLoadedForCurrentPlace {
                        selectedPlaceVM.loadMorePhotos()
                    }
                }
            }
        }
        
        // Show a progress indicator if more photos are being loaded
        if selectedPlaceVM.photoLoadingState == .loading && !images.isEmpty {
            ProgressView()
                .padding()
        }
    }
}
