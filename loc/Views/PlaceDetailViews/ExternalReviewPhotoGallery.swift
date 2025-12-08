import SwiftUI
import UIKit

struct ExternalReviewPhotoGallery: View {
    let onPhotoTapped: ([UIImage], Int) -> Void
    @ObservedObject var photosViewModel: PlacePhotosViewModel
    
    private let heroImageHeight: CGFloat = 200
    private let gridSpacing: CGFloat = 8
    private let cornerRadius: CGFloat = 12
    
    private var photos: [UIImage] {
        photosViewModel.externalReviewPhotos
    }
    
    private var staggeredLayoutItems: [StaggeredItem] {
        guard photos.count > 1 else { return [] }
        
        var items: [StaggeredItem] = []
        let remainingPhotos = Array(photos.dropFirst())
        var currentIndex = 0
        var rowIndex = 0
        
        while currentIndex < remainingPhotos.count {
            let isSinglePhotoRow = rowIndex % 2 == 1
            
            if isSinglePhotoRow {
                let actualIndex = currentIndex + 1
                if actualIndex < photos.count {
                    items.append(.single(actualIndex))
                }
                currentIndex += 1
            } else {
                let indices = (0..<2).compactMap { offset -> Int? in
                    let actualIndex = currentIndex + offset + 1
                    return actualIndex < photos.count ? actualIndex : nil
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
    
    private enum StaggeredItem: Identifiable {
        case single(Int)
        case double([Int])
        
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("More Photos")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            let loadingState = photosViewModel.externalReviewPhotoLoadingState
            
            if photos.isEmpty {
                switch loadingState {
                case .loading, .idle:
                    ProgressView("Loading external photos…")
                        .frame(maxWidth: .infinity)
                case .error(let error):
                    Text("We couldn't load external photos right now. \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .font(.footnote)
                case .loaded:
                    Text("No external photos yet.")
                        .foregroundColor(.gray)
                        .font(.footnote)
                }
            } else {
                VStack(spacing: gridSpacing) {
                    if let firstImage = photos.first {
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
                            onPhotoTapped(photos, 0)
                        }
                    }
                    
                    ForEach(staggeredLayoutItems) { item in
                        switch item {
                        case .single(let actualIndex):
                            GeometryReader { geo in
                                Image(uiImage: photos[actualIndex])
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
                                onPhotoTapped(photos, actualIndex)
                            }
                            .onAppear {
                                photosViewModel.loadMoreExternalReviewPhotosIfNeeded(currentIndex: actualIndex)
                            }
                            
                        case .double(let indices):
                            HStack(spacing: gridSpacing) {
                                ForEach(indices, id: \.self) { actualIndex in
                                    GeometryReader { geo in
                                        Image(uiImage: photos[actualIndex])
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
                                        onPhotoTapped(photos, actualIndex)
                                    }
                                    .onAppear {
                                        photosViewModel.loadMoreExternalReviewPhotosIfNeeded(currentIndex: actualIndex)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if loadingState == .loading && !photosViewModel.externalReviewPhotosFullyLoaded {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 12)
                        Spacer()
                    }
                }
            }
        }
        .padding(.top, 8)
        .onAppear {
            photosViewModel.loadInitialExternalReviewPhotos()
        }
    }
}

