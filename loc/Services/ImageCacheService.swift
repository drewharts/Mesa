import Foundation
import SwiftUI

/// Deduplicates concurrent image download requests for the same URL.
private actor ImageDownloadCoordinator {
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]

    /// Returns the image for the URL, reusing an in-flight download if one exists.
    func fetch(url: URL, download: @Sendable @escaping () async -> UIImage?) async -> UIImage? {
        if let existing = inFlightTasks[url] {
            return await existing.value
        }
        let task = Task { await download() }
        inFlightTasks[url] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: url)
        return result
    }
}

// Singleton class for managing image caching throughout the app
class ImageCacheService {
    static let shared = ImageCacheService()
    
    // Main cache for storing images
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Secondary disk cache
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Set up cache configuration
        imageCache.countLimit = 100 // Max number of objects
        imageCache.totalCostLimit = 50 * 1024 * 1024 // Max 50MB of memory
        
        // Create disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating image cache directory: \(error)")
            }
        }
    }
    
    // Get image from cache
    func getImage(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)
        
        // Check memory cache first
        if let cachedImage = imageCache.object(forKey: key as NSString) {
            return cachedImage
        }
        
        // If not in memory, check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Store in memory cache for faster access next time
            imageCache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    // Store image in cache
    func storeImage(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        
        // Store in memory cache
        imageCache.setObject(image, forKey: key as NSString)
        
        // Also store in disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }
    
    // Generate a cache key from URL
    private func cacheKey(for url: URL) -> String {
        return url.absoluteString.replacingOccurrences(of: "/", with: "_")
    }
    
    // Clear memory cache (but keep disk cache)
    func clearMemoryCache() {
        imageCache.removeAllObjects()
    }
    
    // Clear both memory and disk cache
    func clearAllCache() {
        // Clear memory
        imageCache.removeAllObjects()
        
        // Clear disk
        do {
            try fileManager.removeItem(at: cacheDirectory)
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error clearing image cache directory: \(error)")
        }
    }
    
    // MARK: - Single Image Fetch (with deduplication and downsampling)

    private let downloadCoordinator = ImageDownloadCoordinator()

    /// Fetches an image with cache lookup, request deduplication, and optional downsampling.
    func fetchImage(for url: URL, targetSize: CGSize? = nil) async -> UIImage? {
        if let cached = getImage(for: url) { return cached }

        return await downloadCoordinator.fetch(url: url) { [self] in
            // Re-check cache (another task may have populated it)
            if let cached = self.getImage(for: url) { return cached }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image: UIImage?
                if let targetSize = targetSize {
                    image = Self.downsample(data: data, to: targetSize)
                } else {
                    image = UIImage(data: data)
                }
                if let image = image {
                    self.storeImage(image, for: url)
                }
                return image
            } catch {
                return nil
            }
        }
    }

    /// Downsamples image data to fit within targetSize without loading full resolution into memory.
    private static func downsample(data: Data, to targetSize: CGSize) -> UIImage? {
        let maxDimension = max(targetSize.width, targetSize.height) * UIScreen.main.scale
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else { return nil }

        // Redraw into an opaque context to strip the unnecessary alpha channel.
        // CGImageSource preserves RGBA even for opaque sources (JPEGs), which
        // doubles memory usage and triggers an ImageIO warning on JPEG encoding.
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Batch Loading (Parallel with Caching)
    
    /// Batch load images in parallel with caching
    /// Returns a dictionary mapping URL strings to loaded images
    /// Uses TaskGroup for concurrent downloads - significantly faster than sequential loading
    func loadImages(from urlStrings: [String]) async -> [String: UIImage] {
        var results: [String: UIImage] = [:]
        
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for urlString in urlStrings {
                guard let url = URL(string: urlString) else { continue }
                
                group.addTask {
                    // Check cache first (instant if cached)
                    if let cached = self.getImage(for: url) {
                        return (urlString, cached)
                    }
                    
                    // Download if not cached
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            self.storeImage(image, for: url)
                            return (urlString, image)
                        }
                    } catch {
                        // Silent fail - expected for some URLs
                    }
                    return (urlString, nil)
                }
            }
            
            for await (urlString, image) in group {
                if let image = image {
                    results[urlString] = image
                }
            }
        }
        
        return results
    }
} 