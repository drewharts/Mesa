import SwiftUI

/// Displays an image from a URL with memory + disk caching, request deduplication, and downsampling.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let targetSize: CGSize?
    let placeholder: () -> Placeholder
    let onFailure: (() -> Void)?
    /// Crossfade length when the image arrives from the network; 0 (default) swaps instantly. Cached images never fade.
    let fadeInDuration: Double

    @State private var loadedImage: UIImage?
    @State private var didFail = false

    /// Creates the image view; `onFailure` (last, so trailing-closure placeholders keep working) fires when the URL can't be loaded.
    init(
        url: URL?,
        targetSize: CGSize?,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        onFailure: (() -> Void)? = nil,
        fadeInDuration: Double = 0
    ) {
        self.fadeInDuration = fadeInDuration
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
                    .transition(.opacity)
            } else {
                placeholder()
                    .transition(.opacity)
            }
        }
        .screenshotImagePending(url != nil && loadedImage == nil && !didFail)
        .task(id: url) {
            await loadImage()
        }
    }

    /// Loads image via ImageCacheService (cache -> deduplicated fetch -> downsample -> cache), reporting non-cancelled failures.
    private func loadImage() async {
        didFail = false
        guard let imageURL = url else { loadedImage = nil; return }
        if let cached = ImageCacheService.shared.memoryImage(for: imageURL, targetSize: targetSize) {
            loadedImage = cached
            return
        }
        loadedImage = nil
        let fetched = await ImageCacheService.shared.fetchImage(for: imageURL, targetSize: targetSize)
        if fadeInDuration > 0, fetched != nil {
            withAnimation(.easeOut(duration: fadeInDuration)) { loadedImage = fetched }
        } else {
            loadedImage = fetched
        }
        if loadedImage == nil && !Task.isCancelled {
            didFail = true
            #if DEBUG
            ScreenshotReadiness.shared.imageFailed()
            #endif
            onFailure?()
        }
    }
}
