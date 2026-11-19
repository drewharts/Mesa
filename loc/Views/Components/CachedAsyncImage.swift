import SwiftUI

/// Displays an image from a URL with memory + disk caching, request deduplication, and downsampling.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let targetSize: CGSize?
    let placeholder: () -> Placeholder
    let onFailure: (() -> Void)?

    @State private var loadedImage: UIImage?

    /// Creates the image view; `onFailure` (last, so trailing-closure placeholders keep working) fires when the URL can't be loaded.
    init(
        url: URL?,
        targetSize: CGSize?,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        onFailure: (() -> Void)? = nil
    ) {
        self.url = url
        self.targetSize = targetSize
        self.placeholder = placeholder
        self.onFailure = onFailure
        // A memory-cache hit renders on the first frame: lazily re-created rows (scrolling back) never flash the placeholder.
        _loadedImage = State(initialValue: url.flatMap { ImageCacheService.shared.memoryImage(for: $0, targetSize: targetSize) })
    }

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

    /// Loads image via ImageCacheService (cache -> deduplicated fetch -> downsample -> cache), reporting non-cancelled failures.
    private func loadImage() async {
        guard let imageURL = url else { loadedImage = nil; return }
        if let cached = ImageCacheService.shared.memoryImage(for: imageURL, targetSize: targetSize) {
            loadedImage = cached
            return
        }
        loadedImage = nil
        loadedImage = await ImageCacheService.shared.fetchImage(for: imageURL, targetSize: targetSize)
        if loadedImage == nil && !Task.isCancelled {
            onFailure?()
        }
    }
}
