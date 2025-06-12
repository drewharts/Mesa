import Foundation
import FirebaseStorage
import UIKit

class ImageService: ObservableObject {
    static let shared = ImageService()
    private let storage = FirebaseManager.shared.storage
    private let db = FirebaseManager.shared.db

    private init() {}

    // MARK: - Profile Photos
    // Functions like updateProfilePhoto will go here.

    // Add async version of updateProfilePhoto
    func updateProfilePhoto(userId: String, image: UIImage) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            updateProfilePhoto(userId: userId, image: image) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateProfilePhoto(userId: String, image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
        // Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            let error = NSError(domain: "ProfileFirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
            completion(.failure(error))
            return
        }
        
        // Create a unique filename
        let filename = "profile_photos/\(userId)_\(Date().timeIntervalSince1970).jpg"
        let storageRef = storage.reference().child(filename)
        
        // Upload the image data
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // First, check if user has an existing profile photo
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error checking existing profile photo: \(error.localizedDescription)")
                // Continue with upload even if we can't check existing photo
            }
            
            // Try to delete existing photo if it exists
            if let existingPhotoURL = document?.data()?["profilePhotoURL"] as? String {
                // Extract the filename from the URL
                if let existingPhotoPath = existingPhotoURL.components(separatedBy: "/").last {
                    let existingRef = self.storage.reference().child("profile_photos/\(existingPhotoPath)")
                    existingRef.delete { error in
                        if let error = error {
                            // Only log the error if it's not a "not found" error
                            if (error as NSError).domain != "com.google.HTTPStatus" || (error as NSError).code != 404 {
                                print("Error deleting existing profile photo: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
            
            // Now upload the new photo
            storageRef.putData(imageData, metadata: metadata) { metadata, error in
                if let error = error {
                    print("Error uploading profile photo: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // Wait a brief moment to ensure the upload is fully processed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            print("Error getting download URL: \(error.localizedDescription)")
                            completion(.failure(error))
                            return
                        }
                        
                        guard let downloadURL = url else {
                            let error = NSError(domain: "ProfileFirestoreService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Download URL was nil"])
                            completion(.failure(error))
                            return
                        }
                        
                        // Update the user's profile document with the new URL
                        userRef.updateData([
                            "profilePhotoURL": downloadURL.absoluteString
                        ]) { error in
                            if let error = error {
                                print("Error updating user profile: \(error.localizedDescription)")
                                completion(.failure(error))
                            } else {
                                print("Successfully updated profile photo URL")
                                completion(.success(downloadURL))
                            }
                        }
                    }
                }
            }
        }
    }

        func fetchPhotosFromStorage(urls: [String], completion: @escaping ([UIImage]?, Error?) -> Void) {
        // Early exit for empty URLs
        guard !urls.isEmpty else {
            DispatchQueue.main.async {
                completion([], nil)
            }
            return
        }
        
        var images: [UIImage] = []
        let group = DispatchGroup()
        var lastError: Error?
        
        // Use OperationQueue to limit concurrent downloads
        let downloadQueue = OperationQueue()
        downloadQueue.maxConcurrentOperationCount = 10 // Limit concurrent downloads
        
        for urlString in urls {
            // Skip invalid URLs
            guard let url = URL(string: urlString) else {
                print("Invalid URL: \(urlString)")
                continue
            }
            
            // Check cache first
            if let cachedImage = ImageCacheService.shared.getImage(for: url) {
                images.append(cachedImage)
                continue
            }
            
            group.enter()
            
            // Create download operation
            let operation = BlockOperation {
                // Create a semaphore to handle the async task within the operation
                let semaphore = DispatchSemaphore(value: 0)
                
                var retryCount = 0
                let maxRetries = 2
                
                func attemptDownload() {
                    // Configure the URLRequest with timeout
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 15 // 15 seconds timeout
                    
                    URLSession.shared.dataTask(with: request) { data, response, error in
                        // Handle error with retry logic
                        if let error = error {
                            if retryCount < maxRetries {
                                retryCount += 1
                                print("Retry \(retryCount) for URL: \(urlString)")
                                attemptDownload() // Recursive retry
                                return
                            }
                            
                            print("Error downloading image after \(maxRetries) retries from \(urlString): \(error.localizedDescription)")
                            lastError = error
                            semaphore.signal()
                            group.leave()
                            return
                        }
                        
                        // Process image data
                        if let data = data {
                            // Check for image data size and possibly downsample for large images
                            if data.count > 1024 * 1024 { // If larger than 1MB
                                if let downsampledImage = self.downsampleImage(data: data, to: CGSize(width: 1000, height: 1000)) {
                                    images.append(downsampledImage)
                                    ImageCacheService.shared.storeImage(downsampledImage, for: url)
                                } else if let image = UIImage(data: data) {
                                    images.append(image)
                                    ImageCacheService.shared.storeImage(image, for: url)
                                }
                            } else if let image = UIImage(data: data) {
                                images.append(image)
                                ImageCacheService.shared.storeImage(image, for: url)
                            }
                        }
                        
                        semaphore.signal()
                        group.leave()
                    }.resume()
                }
                
                // Start the download process
                attemptDownload()
                
                // Wait for the async operation to complete
                semaphore.wait()
            }
            
            downloadQueue.addOperation(operation)
        }
        
        // Handle completion
        group.notify(queue: .main) {
            if images.isEmpty && lastError != nil {
                completion(nil, lastError)
            } else {
                completion(images, nil)
            }
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

    func fetchPhotosFromStorage(placeId: String, returnFirstImageOnly: Bool = false, completion: @escaping ([UIImage]?, Error?) -> Void) {
            let storageRef = storage.reference().child("reviews/\(placeId)")
            
            storageRef.listAll { [weak self] (result, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listing files in storage for place \(placeId): \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let result = result else {
                    print("No result returned for storage path reviews/\(placeId)")
                    completion([], nil)
                    return
                }
                
                let itemsToProcess = returnFirstImageOnly ? result.items.prefix(1) : result.items.prefix(9)
                let itemsArray = Array(itemsToProcess) // Convert to array for indexing
                var images: [UIImage] = []
                var lastError: Error? = nil
                
                // Recursive function to fetch images one by one
                func fetchNextImage(index: Int) {
                    // Base case: all items processed
                    if index >= itemsArray.count {
                        DispatchQueue.main.async {
                            completion(images.isEmpty && lastError == nil ? [] : images, lastError)
                        }
                        return
                    }
                    
                    let item = itemsArray[index]
                    item.getData(maxSize: 5 * 1024 * 1024) { data, error in
                        if let error = error {
                            print("Error downloading image \(item.name): \(error.localizedDescription)")
                            lastError = error
                        } else if let data = data, let image = UIImage(data: data) {
                            images.append(image)
                        }
                        
                        // Fetch the next image
                        fetchNextImage(index: index + 1)
                    }
                }
                
                // Start fetching from the first item
                fetchNextImage(index: 0)
            }
        }

    func uploadImagesForReview<T: ReviewProtocol>(
        review: T,
        images: [UIImage],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        // If there are no images, return immediately with an empty array
        guard !images.isEmpty else {
            completion(.success([]))
            return
        }
        
        var downloadURLs: [String] = []
        var errors: [Error] = []

        // A DispatchGroup to wait for all uploads
        let dispatchGroup = DispatchGroup()
        
        for image in images {
            dispatchGroup.enter()
            
            // 1. Generate a unique name for each image
            let imageName = UUID().uuidString
            
            // 2. (Optional) Decide on a path for storing your review images
            //    For example: "reviews/{reviewId}/{imageName}.jpg"
            let storageRef = storage.reference()
                .child("reviews/\(review.id)/\(imageName).jpg")
            
            // 3. Convert the UIImage to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.5) else {
                errors.append(
                    NSError(domain: "FirestoreService", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: "Could not convert image to data"
                    ])
                )
                dispatchGroup.leave()
                continue
            }

            // 4. Upload the image data
            storageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    errors.append(error)
                    dispatchGroup.leave()
                    return
                }
                
                // 5. Once uploaded, fetch the download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        errors.append(error)
                    } else if let downloadURL = url {
                        downloadURLs.append(downloadURL.absoluteString)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        // 6. When all uploads finish, call completion
        dispatchGroup.notify(queue: .main) {
            if let firstError = errors.first {
                completion(.failure(firstError))
            } else {
                completion(.success(downloadURLs))
            }
        }
    }

        // Function to upload an image and update the PlaceList's image field
    func uploadImageAndUpdatePlaceList(userId: String, placeList: PlaceList, image: UIImage, completion: @escaping (Error?) -> Void) {
        // 1. Generate a unique name for the image
        let imageName = UUID().uuidString
        let storageRef = storage.reference().child("placeListPhotos/\(userId)/\(placeList.name)/\(imageName)")

        // 2. Convert the UIImage to data (e.g., JPEG)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(NSError(domain: "FirestoreService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not convert image to data"]))
            return
        }

        // 3. Upload the image data to Firebase Storage
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(error)
                return
            }

            // 4. Get the download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(error)
                    return
                }

                guard let downloadURL = url else {
                    completion(NSError(domain: "FirestoreService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download URL was nil"]))
                    return
                }

                // 5. Update the PlaceList document in Firestore
                let placeListRef = self.db.collection("users").document(userId).collection("placeLists").document(placeList.name)
                placeListRef.updateData([
                    "image": downloadURL.absoluteString
                ]) { error in
                    completion(error)
                }
            }
        }
    }

    func uploadImagesForComment(comment: Comment, images: [UIImage], completion: @escaping (Result<[String], Error>) -> Void) {
        // If there are no images, return immediately with an empty array
        guard !images.isEmpty else {
            completion(.success([]))
            return
        }
        
        var downloadURLs: [String] = []
        var errors: [Error] = []

        // A DispatchGroup to wait for all uploads
        let dispatchGroup = DispatchGroup()
        
        for image in images {
            dispatchGroup.enter()
            
            // 1. Generate a unique name for each image
            let imageName = UUID().uuidString
            
            // 2. Store comment images in a separate folder
            let storageRef = storage.reference()
                .child("comments/\(comment.id)/\(imageName).jpg")
            
            // 3. Convert the UIImage to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.5) else {
                errors.append(
                    NSError(domain: "ImageService", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: "Could not convert image to data"
                    ])
                )
                dispatchGroup.leave()
                continue
            }

            // 4. Upload the image data
            storageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    errors.append(error)
                    dispatchGroup.leave()
                    return
                }
                
                // 5. Once uploaded, fetch the download URL
                storageRef.downloadURL { url, error in
                    if let error = error {
                        errors.append(error)
                    } else if let downloadURL = url {
                        downloadURLs.append(downloadURL.absoluteString)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        // 6. When all uploads finish, call completion
        dispatchGroup.notify(queue: .main) {
            if let firstError = errors.first {
                completion(.failure(firstError))
            } else {
                completion(.success(downloadURLs))
            }
        }
    }
} 