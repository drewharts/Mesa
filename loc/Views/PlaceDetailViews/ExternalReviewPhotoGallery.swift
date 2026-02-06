import SwiftUI

struct ExternalReviewPhotoGallery: View {
    let onPhotoTapped: ([String], Int) -> Void  // URLs instead of UIImages
    @ObservedObject var photosViewModel: PlacePhotosViewModel

    private let heroImageHeight: CGFloat = 200
    private let gridSpacing: CGFloat = 8
    private let cornerRadius: CGFloat = 12

    private var photoItems: [PhotoItem] {
        photosViewModel.externalPhotoItems
    }

    private var staggeredLayoutItems: [StaggeredItem] {
        guard photoItems.count > 1 else { return [] }

        var items: [StaggeredItem] = []
        let remainingPhotos = Array(photoItems.dropFirst())
        var currentIndex = 0
        var rowIndex = 0

        while currentIndex < remainingPhotos.count {
            let isSinglePhotoRow = rowIndex % 2 == 1

            if isSinglePhotoRow {
                let actualIndex = currentIndex + 1
                if actualIndex < photoItems.count {
                    items.append(.single(actualIndex))
                }
                currentIndex += 1
            } else {
                let indices = (0..<2).compactMap { offset -> Int? in
                    let actualIndex = currentIndex + offset + 1
                    return actualIndex < photoItems.count ? actualIndex : nil
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

            if photoItems.isEmpty {
                switch loadingState {
                case .loading, .idle:
                    ProgressView("Loading external photos...")
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
                ZStack(alignment: .bottom) {
                    VStack(spacing: gridSpacing) {
                        if let firstItem = photoItems.first {
                            heroPhotoView(item: firstItem, index: 0)
                        }

                        ForEach(staggeredLayoutItems) { item in
                            staggeredItemView(item)
                        }
                    }

                    if photosViewModel.isRefreshingImages {
                        refreshIndicator
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

    // MARK: - Hero Photo

    /// Displays the hero photo at the top of the gallery.
    private func heroPhotoView(item: PhotoItem, index: Int) -> some View {
        GeometryReader { geo in
            AsyncPhotoItemView(
                item: item,
                width: geo.size.width,
                height: heroImageHeight,
                cornerRadius: cornerRadius
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .frame(height: heroImageHeight)
        .onTapGesture {
            onPhotoTapped(photoItems.map { $0.url }, index)
        }
    }

    // MARK: - Staggered Item View

    /// Routes a staggered item to the appropriate single or double row view.
    @ViewBuilder
    private func staggeredItemView(_ item: StaggeredItem) -> some View {
        switch item {
        case .single(let actualIndex):
            singlePhotoRow(at: actualIndex)

        case .double(let indices):
            doublePhotoRow(indices: indices)
        }
    }

    /// Displays a single photo row in the staggered layout.
    private func singlePhotoRow(at actualIndex: Int) -> some View {
        GeometryReader { geo in
            AsyncPhotoItemView(
                item: photoItems[actualIndex],
                width: geo.size.width,
                height: geo.size.width * 0.6,
                cornerRadius: cornerRadius
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .aspectRatio(5/3, contentMode: .fill)
        .onTapGesture {
            onPhotoTapped(photoItems.map { $0.url }, actualIndex)
        }
        .onAppear {
            photosViewModel.loadMoreExternalReviewPhotosIfNeeded(currentIndex: actualIndex)
        }
    }

    /// Displays a double photo row in the staggered layout.
    private func doublePhotoRow(indices: [Int]) -> some View {
        HStack(spacing: gridSpacing) {
            ForEach(indices, id: \.self) { actualIndex in
                GeometryReader { geo in
                    AsyncPhotoItemView(
                        item: photoItems[actualIndex],
                        width: geo.size.width,
                        height: geo.size.width * 0.8,
                        cornerRadius: cornerRadius
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                }
                .aspectRatio(5/4, contentMode: .fill)
                .onTapGesture {
                    onPhotoTapped(photoItems.map { $0.url }, actualIndex)
                }
                .onAppear {
                    photosViewModel.loadMoreExternalReviewPhotosIfNeeded(currentIndex: actualIndex)
                }
            }
        }
    }

    // MARK: - Refresh Indicator

    private var refreshIndicator: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Refreshing photos...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding(.bottom, 8)
    }
}
