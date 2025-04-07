import Foundation
import SwiftUI

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
} 