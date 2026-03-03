import Foundation
import UIKit
import Supabase
import AVFoundation

class ImageService {
    static let shared = ImageService()

    private init() {}

    // MARK: - Profile Photos
    // Functions like updateProfilePhoto will go here.

    // Add async version of updateProfilePhoto
    func updateProfilePhoto(userId: String, image: UIImage) async throws -> URL {
        print("🔄 [ImageService] updateProfilePhoto called with userId: \(userId)")
        
        let supabase = await SupabaseManager.shared
        
        // Debug authentication status first
        await supabase.debugAuthStatus()
        
        // Convert UIImage to Data (JPEG format)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ [ImageService] Failed to convert image to JPEG data")
            throw NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])
        }
        
        do {
            // Get the authenticated Supabase user ID (this is what RLS policies expect)
            let currentUser = try await supabase.auth.user()
            let supabaseUserId = currentUser.id.uuidString
            
            // Create filename - use simple profile.jpg for easy replacement
            let fileName = "profile.jpg"
            let filePath = "\(supabaseUserId)/\(fileName)"  // Use Supabase user ID
            
            // Get the bucket reference
            let bucket = await supabase.storage.from("profile_photos")
            
            // Upload the new profile photo with upsert to replace existing
            _ = try await bucket.upload(
                filePath,
                data: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: true  // This replaces the existing file
                )
            )
            
            // Get the public URL
            let publicURL = try bucket.getPublicURL(path: filePath)
            
            return publicURL
            
        } catch {
            print("❌ [ImageService] Failed to upload profile photo: \(error)")
            print("❌ [ImageService] Error type: \(type(of: error))")
            print("❌ [ImageService] Error details: \(error.localizedDescription)")
            
            // Try to get more specific error information
            if let storageError = error as? StorageError {
                print("❌ [ImageService] StorageError statusCode: \(String(describing: storageError.statusCode))")
                print("❌ [ImageService] StorageError message: \(storageError.message)")
                print("❌ [ImageService] StorageError error: \(String(describing: storageError.error))")
            }
            
            // Check if it's a network error
            if let urlError = error as? URLError {
                print("❌ [ImageService] URLError code: \(urlError.code)")
                print("❌ [ImageService] URLError description: \(urlError.localizedDescription)")
            }
            
            throw error
        }
    }

    /// Uploads a banner photo to Supabase Storage and returns its public URL.
    func updateBannerPhoto(userId: String, image: UIImage) async throws -> URL {
        let supabase = await SupabaseManager.shared

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert banner image to JPEG data"])
        }

        let currentUser = try await supabase.auth.user()
        let supabaseUserId = currentUser.id.uuidString

        let filePath = "\(supabaseUserId)/banner.jpg"
        let bucket = await supabase.storage.from("profile_photos")

        _ = try await bucket.upload(
            filePath,
            data: imageData,
            options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: true
            )
        )

        let publicURL = try bucket.getPublicURL(path: filePath)
        return publicURL
    }

    func updateProfilePhoto(userId: String, image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            do {
                let url = try await updateProfilePhoto(userId: userId, image: image)
                await MainActor.run {
                    completion(.success(url))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Note: Using upsert: true in upload options automatically replaces existing files
    // No need for separate deletion logic

    func fetchPhotosFromStorage(urls: [String], completion: @escaping ([UIImage]?, Error?) -> Void) {
        // Use the same approach as the working reviewed section
        guard !urls.isEmpty else {
            completion([], nil)
            return
        }
        
        
        Task {
            var loadedImages: [UIImage] = []
            
            // Load images in parallel using TaskGroup (same as reviewed section)
            await withTaskGroup(of: UIImage?.self) { group in
                for urlString in urls {
                    group.addTask {
                        await self.loadImageFromURL(imageUrl: urlString)
                    }
                }
                
                for await image in group {
                    if let image = image {
                        loadedImages.append(image)
                    }
                }
            }
            
            await MainActor.run {
                completion(loadedImages.isEmpty ? nil : loadedImages, nil)
            }
        }
    }
    
    /// Load image directly from URL (same approach as ProfileViewModel)
    private func loadImageFromURL(imageUrl: String) async -> UIImage? {
        // Block legacy storage URLs that are no longer accessible
        if imageUrl.contains("firebasestorage.googleapis.com") {
            print("🚫 [ImageService] Blocking legacy storage URL: \(imageUrl)")
            return nil
        }
        
        guard let url = URL(string: imageUrl) else {
            print("⚠️ [ImageService] Invalid image URL: \(imageUrl)")
            return nil
        }
        
        do {
            // Use the same efficient URLSession configuration as ProfileViewModel
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0  // ✅ Reduced timeout to prevent hanging
            config.timeoutIntervalForResource = 10.0  // ✅ Reduced timeout to prevent hanging
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            if let image = UIImage(data: data) {
                return image
            } else {
                return nil
            }
        } catch {
            print("⚠️ [ImageService] Failed to load image from URL \(imageUrl): \(error.localizedDescription)")
            return nil
        }
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
        
        return imageData
    }

    func fetchPhotosFromStorage(placeId: String, returnFirstImageOnly: Bool = false, completion: @escaping ([UIImage]?, Error?) -> Void) {
        // TODO: Implement with Supabase Storage
        print("⚠️ [ImageService] fetchPhotosFromStorage(placeId:) - Not yet implemented")
        completion([], nil)
    }

    func uploadImagesForPost(
        post: PlacePost,
        images: [UIImage],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        Task {
            do {
                let urls = try await uploadImagesForPostAsync(post: post, images: images)
                await MainActor.run {
                    completion(.success(urls))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Async version of uploadImagesForPost
    func uploadImagesForPostAsync(
        post: PlacePost,
        images: [UIImage]
    ) async throws -> [String] {
        let supabase = await SupabaseManager.shared
        
        guard !images.isEmpty else {
            return []
        }
        
        do {
            let currentUser = try await supabase.auth.user()
            let supabaseUserId = currentUser.id.uuidString
            
            let bucket = await supabase.storage.from("review-photos")
            
            var uploadedUrls: [String] = []
            
            // Upload images sequentially to maintain order
            for (index, image) in images.enumerated() {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    print("❌ [ImageService] Failed to convert image \(index + 1) to JPEG data")
                    continue
                }
                
                // Compress image if needed
                let compressedData = compressImageTo1MB(image) ?? imageData
                
                // Create file path: review-photos/{supabase_user_id}/{post_id}/{image_index}.jpg
                let fileName = "image_\(index + 1).jpg"
                let filePath = "\(supabaseUserId)/\(post.id)/\(fileName)"
                
                _ = try await bucket.upload(
                    filePath,
                    data: compressedData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
                
                let publicURL = try bucket.getPublicURL(path: filePath)
                uploadedUrls.append(publicURL.absoluteString)
            }
            
            return uploadedUrls
            
        } catch {
            print("❌ [ImageService] Failed to upload post images: \(error)")
            print("❌ [ImageService] Error details: \(error.localizedDescription)")
            if let storageError = error as? StorageError {
                print("❌ [ImageService] StorageError statusCode: \(String(describing: storageError.statusCode))")
                print("❌ [ImageService] StorageError message: \(storageError.message)")
                print("❌ [ImageService] StorageError error: \(String(describing: storageError.error))")
            }
            throw error
        }
    }

    // MARK: - Video Upload

    /// Uploads videos for a post and returns paired (videoURL, thumbnailURL) for each.
    func uploadVideosForPostAsync(
        post: PlacePost,
        videoURLs: [URL]
    ) async throws -> [(videoURL: String, thumbnailURL: String)] {
        let supabase = await SupabaseManager.shared

        guard !videoURLs.isEmpty else { return [] }

        let currentUser = try await supabase.auth.user()
        let supabaseUserId = currentUser.id.uuidString
        let videoBucket = await supabase.storage.from("review-videos")
        let photoBucket = await supabase.storage.from("review-photos")

        var results: [(videoURL: String, thumbnailURL: String)] = []

        for (index, localURL) in videoURLs.enumerated() {
            let videoData = try Data(contentsOf: localURL)
            let videoPath = "\(supabaseUserId)/\(post.id)/video_\(index).mp4"

            _ = try await videoBucket.upload(
                videoPath,
                data: videoData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "video/mp4",
                    upsert: true
                )
            )
            let videoPublicURL = try videoBucket.getPublicURL(path: videoPath)

            let thumbnail = try await generateVideoThumbnail(from: localURL)
            let thumbURL = try await uploadThumbnail(
                thumbnail,
                bucket: photoBucket,
                userId: supabaseUserId,
                postId: post.id,
                index: index
            )

            results.append((
                videoURL: videoPublicURL.absoluteString,
                thumbnailURL: thumbURL
            ))
        }

        return results
    }

    /// Generates a thumbnail UIImage from a local video file at 0.5 seconds.
    func generateVideoThumbnail(from url: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        let (cgImage, _) = try await generator.image(at: time)
        return UIImage(cgImage: cgImage)
    }

    /// Uploads a thumbnail image to the photo bucket and returns its public URL string.
    private func uploadThumbnail(
        _ image: UIImage,
        bucket: StorageFileApi,
        userId: String,
        postId: String,
        index: Int
    ) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ImageService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert thumbnail to JPEG"
            ])
        }

        let path = "\(userId)/\(postId)/thumb_\(index).jpg"

        _ = try await bucket.upload(
            path,
            data: data,
            options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: true
            )
        )

        let publicURL = try bucket.getPublicURL(path: path)
        return publicURL.absoluteString
    }

    /// Uploads a cover image for a list to Supabase Storage and updates the place_lists.image column.
    func uploadListCoverImage(listId: String, image: UIImage) async throws -> URL {
        let supabase = await SupabaseManager.shared

        guard let imageData = compressImageTo1MB(image) ?? image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG data"])
        }

        let filePath = "\(listId)/cover.jpg"
        let bucket = await supabase.storage.from("list_covers")

        _ = try await bucket.upload(
            filePath,
            data: imageData,
            options: FileOptions(
                cacheControl: "3600",
                contentType: "image/jpeg",
                upsert: true
            )
        )

        let publicURL = try bucket.getPublicURL(path: filePath)

        // Update the place_lists.image column with the public URL
        try await supabase.client
            .from("place_lists")
            .update(["image": publicURL.absoluteString])
            .eq("id", value: listId)
            .execute()

        print("✅ [ImageService] Uploaded list cover for \(listId): \(publicURL.absoluteString)")
        return publicURL
    }

    func uploadImagesForComment(comment: Comment, images: [UIImage], completion: @escaping (Result<[String], Error>) -> Void) {
        Task {
            do {
                let urls = try await uploadImagesForCommentAsync(comment: comment, images: images)
                await MainActor.run {
                    completion(.success(urls))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Async version of uploadImagesForComment
    func uploadImagesForCommentAsync(comment: Comment, images: [UIImage]) async throws -> [String] {
        let supabase = await SupabaseManager.shared
        
        guard !images.isEmpty else {
            return []
        }
        
        do {
            let currentUser = try await supabase.auth.user()
            let supabaseUserId = currentUser.id.uuidString
            
            let bucket = await supabase.storage.from("comment_photos")
            
            var uploadedUrls: [String] = []
            
            // Upload images sequentially to maintain order
            for (index, image) in images.enumerated() {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    print("❌ [ImageService] Failed to convert comment image \(index + 1) to JPEG data")
                    continue
                }
                
                // Compress image if needed
                let compressedData = compressImageTo1MB(image) ?? imageData
                
                // Create file path: comment-photos/{supabase_user_id}/{comment_id}/{image_index}.jpg
                let fileName = "image_\(index + 1).jpg"
                let filePath = "\(supabaseUserId)/\(comment.id)/\(fileName)"
                
                _ = try await bucket.upload(
                    filePath,
                    data: compressedData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
                
                let publicURL = try bucket.getPublicURL(path: filePath)
                uploadedUrls.append(publicURL.absoluteString)
            }
            
            return uploadedUrls
            
        } catch {
            print("❌ [ImageService] Failed to upload comment images: \(error)")
            print("❌ [ImageService] Error details: \(error.localizedDescription)")
            if let storageError = error as? StorageError {
                print("❌ [ImageService] StorageError statusCode: \(String(describing: storageError.statusCode))")
                print("❌ [ImageService] StorageError message: \(storageError.message)")
                print("❌ [ImageService] StorageError error: \(String(describing: storageError.error))")
            }
            throw error
        }
    }
}
