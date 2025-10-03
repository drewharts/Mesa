//
//  MaxPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/10/25.
//

import SwiftUI

struct MaxPlaceDetailView: View {
    @ObservedObject var viewModel: PlaceDetailViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    // Accept callback for photo tapped
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let _ = selectedPlaceVM.selectedPlace {
                        switch selectedPlaceVM.photoLoadingState {
                        case .idle, .loading:
                            ProgressView("Loading Photos...")
                                .frame(maxWidth: .infinity)
                                .padding()
                            
                        case .loaded:
                            let photos = selectedPlaceVM.photos
                            if !photos.isEmpty {
                                ModernPhotoGallery(images: photos, onImageTapped: { index in
                                    onPhotoTapped(photos, index)
                                })
                                .environmentObject(selectedPlaceVM)
                            } else {
                                Text("No Photos")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            
                        case .error(let error):
                            Text("Failed to load photos: \(error.localizedDescription)")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("No Place Selected")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}
