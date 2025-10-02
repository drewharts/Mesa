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

    // Helper function to create staggered groups: [2, 1, 2, 1, ...]
    private func createStaggeredGroups(from photos: [UIImage]) -> [[UIImage]] {
        var groups: [[UIImage]] = []
        var index = 0

        while index < photos.count {
            if index % 3 == 2 { // Every 3rd position (0-indexed: 2, 5, 8, ...)
                // Single photo
                if index < photos.count {
                    groups.append([photos[index]])
                }
                index += 1
            } else {
                // Two photos
                if index + 1 < photos.count {
                    groups.append([photos[index], photos[index + 1]])
                    index += 2
                } else if index < photos.count {
                    // Only one photo left
                    groups.append([photos[index]])
                    index += 1
                } else {
                    break
                }
            }
        }

        return groups
    }

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

                        // Staggered grid layout: 2 photos, then 1, then 2, then 1, etc.
                        if images.count > 1 {
                            let remainingPhotos = images.dropFirst() // Skip the hero image
                            let photoGroups = createStaggeredGroups(from: Array(remainingPhotos))

                            ForEach(photoGroups.indices, id: \.self) { groupIndex in
                                let group = photoGroups[groupIndex]

                                if group.count == 2 {
                                    // Two photos in a row
                                    HStack(spacing: gridSpacing) {
                                        ForEach(0..<2, id: \.self) { photoIndex in
                                            let actualIndex = groupIndex * 3 + photoIndex + 1 // +1 because we skipped hero
                                            GeometryReader { geo in
                                                Image(uiImage: images[actualIndex])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: geo.size.width, height: geo.size.width * 0.8)
                                                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: cornerRadius)
                                                            .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                                                    )
                                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                            }
                                            .aspectRatio(5/4, contentMode: .fill)
                                            .onTapGesture {
                                                let actualIndex = groupIndex * 3 + photoIndex + 1
                                                onImageTapped(actualIndex)
                                            }
                                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                        }
                                    }
                                } else if group.count == 1 {
                                    // Single photo (full width)
                                    let actualIndex = groupIndex * 3 + 3 // Pattern: group 0 has photos 1,2,3; group 1 has photos 4,5,6, etc.
                                    GeometryReader { geo in
                                        Image(uiImage: images[actualIndex])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geo.size.width, height: geo.size.width * 0.6) // Slightly taller for single photos
                                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: cornerRadius)
                                                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                                            )
                                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                    }
                                    .aspectRatio(5/3, contentMode: .fill) // Wider aspect ratio for single photos
                                    .onTapGesture {
                                        let actualIndex = groupIndex * 3 + 3
                                        onImageTapped(actualIndex)
                                    }
                                    .onAppear {
                                        // Load more photos when nearing the end
                                        if actualIndex == images.count - 3 && !selectedPlaceVM.allPhotosLoadedForCurrentPlace {
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
