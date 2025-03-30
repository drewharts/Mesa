//
//  ProfileFirestoreService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/30/25.
//

import FirebaseFirestore
import FirebaseStorage

class ProfileFirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func updateProfilePhoto(userId: String, image: UIImage) async throws -> URL {
        // Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "ProfileFirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        // Create a unique filename with a more reliable timestamp format
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "profile_photos/\(userId)_\(timestamp).jpg"
        let storageRef = storage.reference().child(filename)
        
        // Upload the image data with metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            // Upload the data
            let result = try await storageRef.putData(imageData, metadata: metadata)
            print("Successfully uploaded image with size: \(result) bytes")
            
            // Get the download URL
            let downloadURL = try await storageRef.downloadURL()
            print("Successfully got download URL: \(downloadURL)")
            
            // Update the user's profile document with the new URL
            let userRef = db.collection("users").document(userId)
            try await userRef.updateData([
                "profilePhotoURL": downloadURL.absoluteString
            ])
            print("Successfully updated user document with new photo URL")
            
            return downloadURL
        } catch {
            print("Error during profile photo update: \(error)")
            throw error
        }
    }
}

