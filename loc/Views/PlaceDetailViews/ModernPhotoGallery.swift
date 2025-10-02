//
//  ModernPhotoGallery.swift
//  loc
//
//  Created by Mesa on 10/2/25.
//

import SwiftUI

struct ModernPhotoGallery: View {
    let images: [UIImage]
    let onImageTapped: (Int) -> Void

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    // Configuration
    private let heroImageHeight: CGFloat = 200
    private let gridSpacing: CGFloat = 8
    private let cornerRadius: CGFloat = 12

    // Calculate grid layout (2 columns for remaining photos)
    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("PHOTOS")
                .font(.subheadline)
                .foregroundColor(.black)
                .fontWeight(.semibold)
                .padding(.bottom, 5)

            if images.isEmpty {
                // Empty state
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
            } else {
                // Photo gallery
                ScrollView {
                    VStack(spacing: gridSpacing) {
                        // Hero image (first photo, if available)
                        if let firstImage = images.first {
                            GeometryReader { geo in
                                Image(uiImage: firstImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: heroImageHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: cornerRadius)
                                            .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .frame(height: heroImageHeight)
                            .onTapGesture {
                                onImageTapped(0)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }

                        // Grid of remaining photos
                        if images.count > 1 {
                            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                                ForEach(1..<images.count, id: \.self) { index in
                                    GeometryReader { geo in
                                        Image(uiImage: images[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: geo.size.width * 0.8) // 4:5 aspect ratio
                                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: cornerRadius)
                                                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                                            )
                                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                    }
                                    .aspectRatio(5/4, contentMode: .fill) // 4:5 aspect ratio
                                    .onTapGesture {
                                        onImageTapped(index)
                                    }
                                    .onAppear {
                                        // Load more photos when nearing the end
                                        if index == images.count - 3 && !selectedPlaceVM.allPhotosLoadedForCurrentPlace {
                                            selectedPlaceVM.loadMorePhotos()
                                        }
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                }
                            }
                        }

                        // Loading indicator
                        if selectedPlaceVM.photoLoadingState == .loading && !images.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 20)
                                Spacer()
                            }
                        }

                        // Bottom spacing
                        Color.clear.frame(height: 20)
                    }
                    .animation(.easeOut(duration: 0.3), value: images.count)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleImages = [
        UIImage(systemName: "photo")!,
        UIImage(systemName: "photo.fill")!,
        UIImage(systemName: "photo.on.rectangle")!,
        UIImage(systemName: "photo.on.rectangle.angled")!,
        UIImage(systemName: "photo.stack")!
    ]

    return ModernPhotoGallery(images: sampleImages) { index in
        print("Tapped image at index: \(index)")
    }
    .padding()
}
