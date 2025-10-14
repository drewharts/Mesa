import Foundation
// import FirebaseStorage  // Temporarily disabled - Firebase removed
import UIKit

class ImageService {
    static let shared = ImageService()

    private init() {}

    // MARK: - Profile Photos
    // Functions like updateProfilePhoto will go here.

    // Add async version of updateProfilePhoto
    func updateProfilePhoto(userId: String, image: UIImage) async throws -> URL {
        // TODO: Implement with Supabase Storage
        throw NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ImageService temporarily disabled - Firebase removed"])
    }

    func updateProfilePhoto(userId: String, image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
        // TODO: Implement with Supabase Storage
        let error = NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ImageService temporarily disabled - Firebase removed"])
        completion(.failure(error))
    }

    func fetchPhotosFromStorage(urls: [String], completion: @escaping ([UIImage]?, Error?) -> Void) {
        // TODO: Implement with Supabase Storage
        print("⚠️ fetchPhotosFromStorage temporarily disabled - Firebase removed")
        completion([], nil)
    }

    private func downsampleImage(data: Data, to pointSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * UIScreen.main.scale
        
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }

    /// Compresses an image to 1MB or less while maintaining reasonable quality
    private func compressImageTo1MB(_ image: UIImage) -> Data? {
        let maxFileSize = 1024 * 1024 // 1MB in bytes
        
        // Start with high quality and gradually reduce if needed
        var compressionQuality: CGFloat = 0.9
        let compressionStep: CGFloat = 0.1
        
        // First, try to resize the image if it's very large
        var workingImage = image
        let maxDimension: CGFloat = 1920 // Max width or height in pixels
        
        if max(image.size.width, image.size.height) > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            workingImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        }
        
        // Now compress the image data
        guard var imageData = workingImage.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        
        // Gradually reduce quality until we reach 1MB or less
        while imageData.count > maxFileSize && compressionQuality > 0.1 {
            compressionQuality -= compressionStep
            guard let newData = workingImage.jpegData(compressionQuality: compressionQuality) else {
                break
            }
            imageData = newData
        }
        
        // If still too large, try more aggressive resizing
        if imageData.count > maxFileSize {
            let aggressiveScale: CGFloat = 0.8
            let newSize = CGSize(
                width: workingImage.size.width * aggressiveScale,
                height: workingImage.size.height * aggressiveScale
            )
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            workingImage.draw(in: CGRect(origin: .zero, size: newSize))
            if let smallerImage = UIGraphicsGetImageFromCurrentImageContext() {
                workingImage = smallerImage
            }
            UIGraphicsEndImageContext()
            
            // Try compression again with the smaller image
            compressionQuality = 0.8
            while compressionQuality > 0.1 {
                if let newData = workingImage.jpegData(compressionQuality: compressionQuality),
                   newData.count <= maxFileSize {
                    imageData = newData
                    break
                }
                compressionQuality -= compressionStep
            }
        }
        
        print("📸 Compressed image from original to \(imageData.count) bytes (target: \(maxFileSize) bytes)")
        return imageData
    }

    func fetchPhotosFromStorage(placeId: String, returnFirstImageOnly: Bool = false, completion: @escaping ([UIImage]?, Error?) -> Void) {
        // TODO: Implement with Supabase Storage
        print("⚠️ fetchPhotosFromStorage(placeId:) temporarily disabled - Firebase removed")
        completion([], nil)
    }

    func uploadImagesForReview<T: ReviewProtocol>(
        review: T,
        images: [UIImage],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        // TODO: Implement with Supabase Storage
        print("⚠️ uploadImagesForReview temporarily disabled - Firebase removed")
        let error = NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ImageService temporarily disabled - Firebase removed"])
        completion(.failure(error))
    }

    // Function to upload an image and update the PlaceList's image field
    func uploadImageAndUpdatePlaceList(userId: String, placeList: PlaceList, image: UIImage, completion: @escaping (Error?) -> Void) {
        // TODO: Implement with Supabase Storage
        print("⚠️ uploadImageAndUpdatePlaceList temporarily disabled - Firebase removed")
        let error = NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ImageService temporarily disabled - Firebase removed"])
        completion(error)
    }

    func uploadImagesForComment(comment: Comment, images: [UIImage], completion: @escaping (Result<[String], Error>) -> Void) {
        // TODO: Implement with Supabase Storage
        print("⚠️ uploadImagesForComment temporarily disabled - Firebase removed")
        let error = NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "ImageService temporarily disabled - Firebase removed"])
        completion(.failure(error))
    }
}