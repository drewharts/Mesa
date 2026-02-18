import SwiftUI

/// Displays an image from a URL with memory + disk caching, request deduplication, and downsampling.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let targetSize: CGSize?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    /// Loads image via ImageCacheService (cache -> deduplicated fetch -> downsample -> cache).
    private func loadImage() async {
        loadedImage = nil
        guard let imageURL = url else { return }
        loadedImage = await ImageCacheService.shared.fetchImage(for: imageURL, targetSize: targetSize)
    }
}
