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

    // Computed property to create staggered layout items
    private var staggeredLayoutItems: [StaggeredItem] {
        guard images.count > 1 else { return [] }

        var items: [StaggeredItem] = []
        let remainingPhotos = Array(images.dropFirst()) // Skip hero image
        var currentIndex = 0
        var rowIndex = 0

        while currentIndex < remainingPhotos.count {
            let isSinglePhotoRow = rowIndex % 2 == 1

            if isSinglePhotoRow {
                // Single photo row
                let actualIndex = currentIndex + 1 // +1 because we skipped hero
                if actualIndex < images.count {
                    items.append(.single(actualIndex))
                }
                currentIndex += 1
            } else {
                // Two photo row
                let indices = (0..<2).compactMap { photoIndex in
                    let actualIndex = currentIndex + photoIndex + 1 // +1 because we skipped hero
                    return actualIndex < images.count ? actualIndex : nil
                }
                if !indices.isEmpty {
                    items.append(.double(indices))
                }
                currentIndex += indices.count
            }
            rowIndex += 1
        }

        return items
    }

    // Enum to represent different layout items
    private enum StaggeredItem: Identifiable {
        case single(Int) // Single photo with its index
        case double([Int]) // Two photos with their indices

    var id: String {
        switch self {
        case .single(let index):
            return "single_\(index)"
        case .double(let indices):
            return "double_\(indices.map(String.init).joined(separator: "_"))"
        }
    }
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
                        ForEach(staggeredLayoutItems) { item in
                            switch item {
                            case .single(let actualIndex):
                                // Single photo row
                                GeometryReader { geo in
                                    Image(uiImage: images[actualIndex])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geo.size.width, height: geo.size.width * 0.6)
                                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                                        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: cornerRadius)
                                                .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                                        )
                                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                }
                                .aspectRatio(5/3, contentMode: .fill)
                                .onTapGesture {
                                    onImageTapped(actualIndex)
                                }
                                .onAppear {
                                    // Load more photos when nearing the end
                                    if actualIndex == images.count - 3 && !selectedPlaceVM.allPhotosLoadedForCurrentPlace {
                                        selectedPlaceVM.loadMorePhotos()
                                    }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))

                            case .double(let indices):
                                // Two photo row
                                HStack(spacing: gridSpacing) {
                                    ForEach(indices, id: \.self) { actualIndex in
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
                                            onImageTapped(actualIndex)
                                        }
                                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                    }
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
