//
//  MapAnnotationService.swift
//  loc
//
//  Created by Your Name on \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))
//

import Foundation
import UIKit
import Combine
import FirebaseFirestore // Add import if needed

class MapAnnotationService: ObservableObject {
    
    @Published private(set) var placeAnnotationImages: [String: UIImage] = [:] // Place ID -> Annotation Image
    
    // Cache for user profile images to avoid redundant fetching/processing
    private var userProfilePhotos: [String: UIImage] = [:] // User ID -> Profile Image
    
    // Dependencies
    private let firestoreService: FirestoreService
    private weak var detailPlaceViewModel: DetailPlaceViewModel? // Use weak to avoid retain cycles
    private var currentUserId: String? // To be set later
    
    init(firestoreService: FirestoreService, detailPlaceViewModel: DetailPlaceViewModel) {
        self.firestoreService = firestoreService
        self.detailPlaceViewModel = detailPlaceViewModel
        print("MapAnnotationService initialized")
    }
    
    //what needs to be done to build all annotations
        // 1. Get user's favorite places
        // 2. Get user's placeLists
        // 3. Get user's following
            // 1. Get each profile picture
            // 2. Get each Following favorite places
            // 3. Get each Following placeLists
            
    
    // Method to set the user ID after login
    func setCurrentUserId(_ userId: String) {
        self.currentUserId = userId
        print("MapAnnotationService: Current user ID set to \(userId)")
        // Potentially trigger fetches or updates now that we know the user
    }
    
    // MARK: - Public Methods
    
    /// Updates or creates the annotation image for a specific place ID.
    /// Needs access to the list of users who saved the place and their profile images.
    func updateAnnotationImage(for placeId: String, savers: [User]) {
        // 1. Ensure profile photos for savers are loaded/cached (implementation needed)
        // 2. Get the first three profile images using cached photos
        // 3. Generate the combined image
        // 4. Update placeAnnotationImages
        // 5. Notify observers (implicit with @Published)
        
        // Placeholder:
        // ensureProfilePhotosLoaded(for: savers) { [weak self] in
        //     guard let self = self else { return }
        //     let (img1, img2, img3) = self.getFirstThreeProfileImages(from: savers)
        //     self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: img1, image2: img2, image3: img3)
        // }
        print("Placeholder: Updating annotation for \(placeId)")
    }
    
    /// Forces a rebuild of all known annotation images.
    /// Needs access to all relevant places and their savers.
    func rebuildAllAnnotations(allPlacesSavers: [String: [User]]) {
        print("Placeholder: Rebuilding all annotations")
        placeAnnotationImages.removeAll() // Clear existing ones
        userProfilePhotos.removeAll() // Clear cached profile photos if necessary (or manage cache expiry)
        
        // Placeholder loop:
        // for (placeId, savers) in allPlacesSavers {
        //     updateAnnotationImage(for: placeId, savers: savers)
        // }
        
        // Consider notifying map view explicitly after rebuild if needed
        // NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)
    }
    
    /// Updates the cached profile photo for a user. Called when a photo changes.
    func updateUserProfilePhoto(_ photo: UIImage?, for userId: String) {
        print("Updating cached profile photo for user \(userId)")
        userProfilePhotos[userId] = photo
        // TODO: Find all place annotations potentially affected by this user and trigger updates.
        // This requires knowing which places this user has saved.
    }
    
    // MARK: - Private Helpers (To be moved from ProfileViewModel)
    
    private func ensureProfilePhotosLoaded(for users: [User], completion: @escaping () -> Void) {
        // Logic to fetch/load profile photos if not already in userProfilePhotos cache
        // Similar to the logic in ProfileViewModel, but adapted for this service
        print("Placeholder: Ensuring photos loaded for \(users.count) users")
        // For now, assume they are loaded and call completion immediately
        DispatchQueue.main.async {
            completion()
        }
    }
    
    private func getFirstThreeProfileImages(from users: [User]) -> (UIImage?, UIImage?, UIImage?) {
        // Logic to get the first three user images from the userProfilePhotos cache
        // Similar to ProfileViewModel's getFirstThreeProfileImages
        print("Placeholder: Getting first three profile images")
        let defaultImage = UIImage(named: "defaultProfile") // Make sure this asset exists
        
        guard !users.isEmpty else {
             return (defaultImage, nil, nil)
        }

        let firstThreeUsers = users.prefix(3)
        let images = firstThreeUsers.map { user -> UIImage? in
            return self.userProfilePhotos[user.id] ?? defaultImage
        }

        let paddedImages = (images + [nil, nil, nil]).prefix(3)
        return (paddedImages[0], paddedImages[1], paddedImages[2])
    }

    private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
        // Exact copy of the method from ProfileViewModel
        let totalSize = CGSize(width: 80, height: 40)
        let singleCircleSize = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: totalSize)

        return renderer.image { context in
            let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let secondRect = CGRect(x: 15, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let thirdRect = CGRect(x: 30, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)

            func drawCircularImage(_ image: UIImage?, in rect: CGRect) {
                guard let image = image else { return }
                context.cgContext.saveGState()
                let circlePath = UIBezierPath(ovalIn: rect)
                circlePath.addClip()
                image.draw(in: rect)
                context.cgContext.setStrokeColor(UIColor.white.cgColor)
                context.cgContext.setLineWidth(1.0) // Adjusted line width
                // Correct inset calculation: inset by half the line width
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5)) 
                context.cgContext.restoreGState()
            }

            // Draw in reverse order so the first image is on top
            if image3 != nil { drawCircularImage(image3, in: thirdRect) }
            if image2 != nil { drawCircularImage(image2, in: secondRect) }
            if image1 != nil { drawCircularImage(image1, in: firstRect) }
        }
    }
    
    // MARK: - Potential Dependencies (Example)
    // private let firestoreService: FirestoreService // If fetching photos here
    // private weak var detailPlaceViewModel: DetailPlaceViewModel // To get savers
}

// Placeholder User struct if not globally available
// struct User: Identifiable {
//    let id: String
//    var profilePhotoURL: URL?
// } 
