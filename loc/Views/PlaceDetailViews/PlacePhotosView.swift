//
//  PlacePhotosView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/10/25.
//

import SwiftUI
import CoreLocation

struct PlacePhotosView: View {
    @ObservedObject var viewModel: PlacePhotosViewModel
    
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.place != nil {
                        switch viewModel.photoLoadingState {
                        case .idle, .loading:
                            ProgressView("Loading Photos...")
                                .frame(maxWidth: .infinity)
                                .padding()
                            
                        case .loaded:
                            let allPhotos = viewModel.combinedPhotos
                            let displayPhotos = Array(allPhotos.prefix(10))
                            let overflowCount = max(0, allPhotos.count - 10)

                            if !displayPhotos.isEmpty {
                                ModernPhotoGallery(
                                    images: displayPhotos,
                                    onImageTapped: { index in
                                        // When tapping "+X more" photo, pass all photos to viewer
                                        onPhotoTapped(allPhotos, index)
                                    },
                                    overflowCount: overflowCount,
                                    allPhotosForViewer: allPhotos,
                                    photosViewModel: viewModel
                                )
                            } else {
                                // Show empty state when no photos available
                                VStack(spacing: 16) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray.opacity(0.5))

                                    Text("No photos yet")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
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
        .onAppear {
            viewModel.loadInitialExternalReviewPhotos()
        }
    }
}

// MARK: - Preview
#Preview {
    let services = ServiceContainer.shared
    let selectedPlaceVM = SelectedPlaceViewModel(
        locationManager: LocationManager(),
        postService: services.postService,
        placeService: services.placeService,
        userService: services.userService,
        imageService: services.imageService
    )
    
    let photosViewModel = PlacePhotosViewModel(
        postService: services.postService,
        selectedPlaceVM: selectedPlaceVM
    )
    
    // Create a mock place with all properties
    let mockPlace: DetailPlace = {
        var place = DetailPlace()
        place.name = "Sample Restaurant"
        place.address = "123 Main St"
        place.coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        return place
    }()
    
    // Simulate place selection
    selectedPlaceVM.selectedPlace = mockPlace
    
    return PlacePhotosView(
        viewModel: photosViewModel,
        onPhotoTapped: { photos, index in
            print("Tapped photo at index: \(index)")
        }
    )
    .padding()
}
