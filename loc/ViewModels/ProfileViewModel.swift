//  ProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import Combine
import Foundation
import UIKit
import CoreLocation


// MARK: - List Place Pagination Model
struct ListPlacePagination {
    var allPlaceIds: [String] = []
    var loadedPlaceIds: [String] = []
    var currentPage: Int = 0
    var placesPerPage: Int = 5
    var isLoadingMore: Bool = false
    var hasMorePlaces: Bool = true
    
    var displayedPlaceIds: [String] {
        return loadedPlaceIds
    }
    
    var totalPlaces: Int {
        return allPlaceIds.count
    }
    
    var loadedCount: Int {
        return loadedPlaceIds.count
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: ProfileData? 
    @Published var userPicture: UIImage?
    @Published var userLists: [PlaceList] = []
    @Published var userListsPlaces: [String: [String]] = [:] // [listId: [placeId]]
    @Published var placeListCounts: [UUID: Int] = [:]
    @Published var userFavorites: [String] = [] // Legacy - full place IDs
    @Published var lightweightFavorites: [FavoritePlace] = [] // New - lightweight data for display
    @Published var lightweightPlaceLists: [LightweightPlaceList] = [] // New - lightweight place lists by proximity
    @Published var lightweightPlaceListPlaces: [String: [LightweightPlace]] = [:] // [listId: places]
    @Published var lightweightMyPlaces: [LightweightPlace] = [] // Lightweight my places for tiles
    @Published var isLoadingMoreMyPlaces: Bool = false
    @Published var hasMoreMyPlaces: Bool = true
    @Published var lightweightExternalPlaces: [LightweightPlace] = [] // Lightweight external/TikTok places for tiles
    @Published var isLoadingMoreExternalPlaces: Bool = false
    @Published var hasMoreExternalPlaces: Bool = true
    @Published var isLoadingMorePlaceLists: Bool = false
    @Published var hasMorePlaceLists: Bool = true
    var placeListsCurrentPage: Int = 1
    @Published var userFollowing: [ProfileData] = []
    @Published var userFollowers: [ProfileData] = []
    @Published var myPlaces: [String] = [] // Legacy - keep for compatibility
    @Published var userExternalPlaces: [String: ExternalPlace] = [:] // PlaceId -> ExternalPlace
    @Published var recentlyCreatedListId: UUID?
    
    private let userService: UserService
    private let imageService: ImageService
    private let placeService: PlaceService
    private let reviewService: ReviewService
     internal let detailPlaceViewModel: DetailPlaceViewModel
     private let userSession: UserSession
    private var deepLinkManager: DeepLinkManager?
    private var deepLinkViewModel: DeepLinkViewModel?
    var userProfileViewModel: UserProfileViewModel?
    weak var mapViewModel: MapViewModel?  // For updating friends' places in viewport

     @Published var showMaxFavoritesAlert: Bool = false
     @Published var isLoading: Bool = true
     @Published var isUploadingProfilePhoto: Bool = false
     private var loadingTasks: Int = 0
     @Published var followersCount: Int = 0
     @Published var followingCount: Int = 0
     
     // Follow error handling
     @Published var showFollowError: Bool = false
     @Published var followErrorMessage: String = ""
    
    // Separate loading states for counts
    @Published var isFollowersLoading: Bool = true
    @Published var isFollowingLoading: Bool = true
    @Published var isMyPlacesLoading: Bool = true
    // Popup list loading states
    @Published var isFollowersListLoading: Bool = false
    @Published var isFollowingListLoading: Bool = false
    
    // TikTok processing state
    @Published var isProcessingTikTok: Bool = false
    @Published var isWaitingForPlaceDetail: Bool = false
    @Published var tikTokImportError: String? = nil
    @Published var importedPlaces: [DetailPlace] = []
    @Published var isShowingPlaceSelection: Bool = false
    @Published var isShowingNoPlacesFound: Bool = false
    @Published var noPlacesFoundTikTokUrl: String = ""
    
    // Lazy loading state for lists
    @Published var loadedListIds: Set<UUID> = []
    @Published var loadingListIds: Set<UUID> = []
    
    // Pagination state for places within each list
    @Published var listPlacePagination: [String: ListPlacePagination] = [:] // [listId: pagination state]
    
    // Performance optimization: image preloading cache
    @Published var preloadedImages: [String: Bool] = [:] // [imageURL: isPreloaded]

    // Add deduplication mechanism for TikTok URLs
    private var recentlyProcessedURLs: Set<String> = []

    // Concurrency control for list loading
    private let maxConcurrentListLoads = 2
    private var activeListLoadTasks: [UUID: Task<Void, Never>] = [:]
    
    // Pagination for reviewed places
    @Published var isLoadingReviewedPlaces: Bool = false
    @Published var isLoadingMoreReviews: Bool = false
    private var _hasMoreReviews: Bool = true
    private var currentReviewPage: Int = 0
    private let reviewsPerPage: Int = 8
    var allReviewedPlaceIds: [String] = []
    private var loadedReviewedPlaceIds: [String] = []
    
    // Pagination for TikTok places
    @Published var isLoadingTikTokPlaces: Bool = false
    
    // Place notes
    @Published var placeNotes: [String: PlaceNote] = [:] // [placeId: PlaceNote]
    
    // TikTok place flags
    @Published var tikTokPlaceFlags: [String: TikTokPlaceFlag] = [:] // [placeId: TikTokPlaceFlag]
    @Published var isLoadingMoreTikTokPlaces: Bool = false
    private var _hasMoreTikTokPlaces: Bool = true
    private var currentTikTokPage: Int = 0
    private let tikTokPlacesPerPage: Int = 8
    var allTikTokPlaceIds: [String] = []
    private var loadedTikTokPlaceIds: [String] = []
    
    // Location manager for distance calculations
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    init(userSession: UserSession, userService: UserService, detailPlaceViewModel: DetailPlaceViewModel, imageService: ImageService, placeService: PlaceService, reviewService: ReviewService, locationManager: LocationManager, deepLinkManager: DeepLinkManager? = nil, deepLinkViewModel: DeepLinkViewModel? = nil, userProfileViewModel: UserProfileViewModel? = nil) {
         self.userService = userService
         self.detailPlaceViewModel = detailPlaceViewModel
        self.userSession = userSession
        self.imageService = imageService
        self.placeService = placeService
        self.reviewService = reviewService
        self.locationManager = locationManager
        self.deepLinkManager = deepLinkManager
        self.deepLinkViewModel = deepLinkViewModel
        self.userProfileViewModel = userProfileViewModel
        
        // Observe location changes using Combine
        setupLocationObserver()
        
        // Observe TikTok multiple places notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TikTokMultiplePlacesFound"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let places = notification.userInfo?["places"] as? [DetailPlace] {
                Task { @MainActor in
                    self?.handleMultiplePlaces(places)
                }
            }
        }
     }
    
    private func setupLocationObserver() {
        // Sort immediately when location becomes available (no need to wait for places to load)
        locationManager.$currentLocation
            .dropFirst() // Skip the initial nil value
            .sink { [weak self] location in
                if location != nil && !(self?.hasPerformedInitialSort ?? false) {
                    Task { @MainActor in
                        self?.sortListsByDistance()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
     func changeProfilePhoto(_ newImage: UIImage) async {
        print("🔄 [ProfileViewModel] changeProfilePhoto called")
        
        // Set loading state and update UI immediately on main thread
        await MainActor.run {
            self.isUploadingProfilePhoto = true
            // Update UI immediately to show the new image for instant feedback
            self.userPicture = cropToSquare(newImage)
        }
        
        guard let userId = user?.id else { 
            print("❌ [ProfileViewModel] No user ID found - user is nil")
            await MainActor.run {
                self.isUploadingProfilePhoto = false
            }
            return 
        }
        
        print("🔍 [ProfileViewModel] User ID: \(userId)")
        print("🔍 [ProfileViewModel] User object: \(String(describing: user))")
        
        let croppedImage = cropToSquare(newImage)
        print("🔍 [ProfileViewModel] Image cropped, size: \(croppedImage.size)")
        
        do {
            print("🚀 [ProfileViewModel] Starting profile photo upload...")
            let url = try await imageService.updateProfilePhoto(userId: userId, image: croppedImage)
            print("✅ [ProfileViewModel] Upload successful, URL: \(url)")
            
            // Update the users table with the new profile photo URL
            do {
                print("🔄 [ProfileViewModel] Updating users table with new profile photo URL...")
                try await updateProfilePhotoInDatabase(userId: userId, photoURL: url)
                print("✅ [ProfileViewModel] Database updated successfully")
            } catch {
                print("⚠️ [ProfileViewModel] Failed to update database, but upload succeeded: \(error)")
            }
            
            // Update local user and userPicture on main thread
            await MainActor.run {
                self.user?.profilePhotoURL = url
                self.userPicture = croppedImage
                self.isUploadingProfilePhoto = false
                print("✅ [ProfileViewModel] Local state updated successfully")
            }
        } catch {
            print("❌ [ProfileViewModel] Failed to upload profile photo: \(error)")
            print("❌ [ProfileViewModel] Error type: \(type(of: error))")
            print("❌ [ProfileViewModel] Error details: \(error.localizedDescription)")
            
            // Revert the image on error and clear loading state
            await MainActor.run {
                self.isUploadingProfilePhoto = false
                // Keep the current userPicture or revert to previous state
                print("❌ [ProfileViewModel] Reverting image due to upload failure")
            }
        }
    }
    
     /// Update the users table with the new profile photo URL
     private func updateProfilePhotoInDatabase(userId: String, photoURL: URL) async throws {
        let supabase = await SupabaseManager.shared
        
        // Update the users table with the new profile_photo_url
        try await supabase.client
            .from("users")
            .update(["profile_photo_url": photoURL.absoluteString])
            .eq("id", value: userId)
            .execute()
        
        print("✅ [ProfileViewModel] Updated users table with new profile photo URL: \(photoURL)")
    }
    
     private func cropToSquare(_ image: UIImage) -> UIImage {
         let cgImage = image.cgImage!
         let contextImage = UIImage(cgImage: cgImage)
         let contextSize = contextImage.size
        
         // Get the size of the square
         let size = min(contextSize.width, contextSize.height)
        
         // Calculate the crop rect
         let x = (contextSize.width - size) / 2
         let y = (contextSize.height - size) / 2
         let cropRect = CGRect(x: x * image.scale,
                             y: y * image.scale,
                             width: size * image.scale,
                             height: size * image.scale)
        
         // Create the cropped image
         if let croppedCGImage = cgImage.cropping(to: cropRect) {
             return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
         }
        
         return image
     }
    
     func toggleFollowUser(userId: String) {
        guard let currentUserId = user?.id else { return }
        
        // Store original state for potential rollback
        let originalFollowingState = userFollowing.contains(where: { $0.id == userId })
        let originalFollowingCount = followingCount
        let originalUserFollowing = userFollowing
        
        if userFollowing.contains(where: { $0.id == userId }) {
            // Optimistic update: immediately change UI
            DispatchQueue.main.async {
                self.userFollowing.removeAll { $0.id == userId }
                self.followingCount = max(0, self.followingCount - 1)
            }
            
            // Note: Friend tracking is now handled by PostgreSQL function - no need to update MapViewModel
            
            // Make the actual API call
            userService.unfollowUser(followerId: currentUserId, followingId: userId) { [weak self] success, error in
                if !success {
                    // Revert on failure
                    DispatchQueue.main.async {
                        self?.userFollowing = originalUserFollowing
                        self?.followingCount = originalFollowingCount
                        // Show error alert
                        self?.showFollowError = true
                        self?.followErrorMessage = "Failed to unfollow user. Please try again."
                    }
                }
            }
        } else {
            // Optimistic update: immediately change UI
            DispatchQueue.main.async {
                self.followingCount += 1
            }
            
            // Make the actual API call
            userService.followUser(followerId: currentUserId, followingId: userId) { [weak self] success, error in
                if success {
                    // Fetch the ProfileData for the followed user and add to userFollowing
                    self?.userService.fetchUserById(userId: userId) { result in
                        if case .success(let profileData) = result {
                            DispatchQueue.main.async {
                                self?.userFollowing.append(profileData)
                                // Note: Friend tracking is now handled by PostgreSQL function
                            }
                        }
                    }
                } else {
                    // Revert on failure
                    DispatchQueue.main.async {
                        self?.userFollowing = originalUserFollowing
                        self?.followingCount = originalFollowingCount
                        // Show error alert
                        self?.showFollowError = true
                        self?.followErrorMessage = "Failed to follow user. Please try again."
                    }
                }
            }
        }
    }
    
    /// Update friend IDs in MapViewModel for viewport filtering
    // updateMapViewModelFriendIds removed - friend tracking is now handled by the PostgreSQL function
    
     private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
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
                 context.cgContext.setLineWidth(1.0)
                 context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
                 context.cgContext.restoreGState()
             }
            
             if image3 != nil { drawCircularImage(image3, in: thirdRect) }
             if image2 != nil { drawCircularImage(image2, in: secondRect) }
             if image1 != nil { drawCircularImage(image1, in: firstRect) }
         }
     }
    
     func isPlaceInList(listId: UUID, placeId: String) -> Bool {
         let listIdString = listId.uuidString
         let places = userListsPlaces[listIdString] ?? []
         return places.contains(placeId)
     }
    
     func addPlaceToList(listId: UUID, place: DetailPlace) {
        let listIdString = listId.uuidString
        guard let userId = userSession.currentUserId else {
            return
        }
        // Find the list in userLists
        guard let listIndex = userLists.firstIndex(where: { $0.id == listId }) else {
            return
        }

        // Check if this place has associated external place data (TikTok data)
        // and merge it if the current place doesn't have TikTok videos
        var updatedPlace = place
        if place.tikTokVideos == nil || place.tikTokVideos?.isEmpty == true {
            if let externalPlace = userExternalPlaces[place.id.uuidString] {
                // Merge TikTok data from external place
                updatedPlace = mergeTikTokData(into: place, from: externalPlace)
            }
        }

        // Convert DetailPlace to Place for FirestoreService
        let placeForList = updatedPlace.toPlace()

        // Update local userListsPlaces
        var places = userListsPlaces[listIdString] ?? []
        if !places.contains(updatedPlace.id.uuidString) {
            places.append(updatedPlace.id.uuidString)
            userListsPlaces[listIdString] = places
        }

        // Update the places array in the PlaceList
        if !userLists[listIndex].places.contains(where: { $0.id == updatedPlace.id }) {
            userLists[listIndex].places.append(placeForList)
        }

        // Persist to Firestore
        placeService.addPlaceToList(userId: userId, listName: listIdString, place: placeForList)

        // Update DetailPlaceViewModel's places dictionary for immediate UI update
        // Always update the place to ensure TikTok data and other properties are current
        detailPlaceViewModel.places[updatedPlace.id.uuidString] = updatedPlace
        
        // Add current user as saver so places appear on map with profile picture
        if detailPlaceViewModel.placeSavers[updatedPlace.id.uuidString] == nil {
            detailPlaceViewModel.placeSavers[updatedPlace.id.uuidString] = [userId]
        } else if !detailPlaceViewModel.placeSavers[updatedPlace.id.uuidString]!.contains(userId) {
            detailPlaceViewModel.placeSavers[updatedPlace.id.uuidString]!.append(userId)
        }

        // Recalculate map annotations to include the new place
        detailPlaceViewModel.calculateAnnotationPlaces()
        
        // Recalculate average coordinates for this list
        recalculateAverageCoordinates(for: listId)
        
        // Reset pagination to include the new place
        resetListPagination(listId: listId)
        
        // Skip sorting for individual place additions to avoid frequent re-sorting
    }

    /// Merge TikTok data from an ExternalPlace into a DetailPlace
    private func mergeTikTokData(into detailPlace: DetailPlace, from externalPlace: ExternalPlace) -> DetailPlace {
        // Create a copy of the DetailPlace with TikTok data merged in
        var mergedPlace = detailPlace

        // If the external place has TikTok videos, convert and add them to the detail place
        if !externalPlace.tiktokVideos.isEmpty {
            let tikTokVideos = externalPlace.tiktokVideos.compactMap { convertExternalTikTokVideoToTikTokVideo($0) }
            mergedPlace.tikTokVideos = tikTokVideos
        }

        return mergedPlace
    }
    
    /// Convert ExternalTikTokVideo to TikTokVideo
    private func convertExternalTikTokVideoToTikTokVideo(_ externalVideo: ExternalTikTokVideo) -> TikTokVideo? {
        let tikTokAuthor = TikTokAuthor(
            displayName: externalVideo.author.displayName,
            url: "", // Not available in external format
            username: externalVideo.author.username
        )
        
        return TikTokVideo(
            videoID: externalVideo.videoId,
            url: externalVideo.url,
            title: nil, // Not available in external format
            caption: nil, // Not available in external format
            embedHTML: externalVideo.embedHtml,
            thumbnailURL: externalVideo.thumbnailUrl,
            author: tikTokAuthor,
            hashtags: externalVideo.hashtags,
            createdAt: externalVideo.createdAt
        )
    }

     func removePlaceFromList(listId: UUID, place: DetailPlace) {
         let listIdString = listId.uuidString
         guard
             var places = userListsPlaces[listIdString],
             let index = places.firstIndex(of: place.id.uuidString),
             let userId = userSession.currentUserId,
             let list = userLists.first(where: { $0.id == listId })
         else {
             return
         }

         places.remove(at: index)
         userListsPlaces[listIdString] = places
         
         let placeForList = place.toPlace()

         placeService.removePlaceFromList(userId: userId, listId: list.id.uuidString, placeId: placeForList.id.uuidString) { error in
             if let error = error {
                 print("❌ Error removing place from list: \(error)")
             } else {
                 print("✅ Successfully removed place from list")
             }
         }
         
         // Recalculate average coordinates for this list
         recalculateAverageCoordinates(for: listId)
         
         // Reset pagination to reflect the removed place
         resetListPagination(listId: listId)
         
         // Skip sorting for individual place removals to avoid frequent re-sorting
     }
    
     func addFavoritePlace(place: DetailPlace) {
        guard let userId = userSession.currentUserId else { return }
        // Prevent duplicates and enforce max 6 favorites
        if userFavorites.count >= 6 {
            showMaxFavoritesAlert = true
            return
        }
        if !userFavorites.contains(place.id.uuidString) {
            userFavorites.append(place.id.uuidString)
            userService.addProfileFavorite(userId: userId, placeId: place.id.uuidString) { error in
                if let error = error {
                    print("❌ Error adding profile favorite: \(error)")
                } else {
                    print("✅ Successfully added profile favorite")
                }
            }
            
            // Add current user as saver so favorite places appear on map with profile picture
            if detailPlaceViewModel.placeSavers[place.id.uuidString] == nil {
                detailPlaceViewModel.placeSavers[place.id.uuidString] = [userId]
            } else if !detailPlaceViewModel.placeSavers[place.id.uuidString]!.contains(userId) {
                detailPlaceViewModel.placeSavers[place.id.uuidString]!.append(userId)
            }
            
            // Recalculate map annotations to include the new favorite place
            detailPlaceViewModel.calculateAnnotationPlaces()
        }
    }
    
    func removeFavoritePlace(place: DetailPlace) {
        guard let userId = userSession.currentUserId else { return }
        if let index = userFavorites.firstIndex(of: place.id.uuidString) {
            userFavorites.remove(at: index)
            userService.removeProfileFavorite(userId: userId, placeId: place.id.uuidString) { error in
                if let error = error {
                    print("❌ Error removing profile favorite: \(error)")
                } else {
                    print("✅ Successfully removed profile favorite")
                }
            }
        }
    }
    
    func isPlaceFavorite(placeId: String) -> Bool {
        return userFavorites.contains(placeId)
    }
    
    // MARK: - Place Notes
    
    func savePlaceNote(for placeId: String, note: String?, link: String?) {
        guard let userId = userSession.currentUserId else { return }
        
        let placeNote = PlaceNote(placeId: placeId, userId: userId, note: note, link: link)
        
        userService.savePlaceNote(note: placeNote) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.placeNotes[placeId] = placeNote
                }
            } else if let error = error {
                print("Error saving place note: \(error.localizedDescription)")
            }
        }
    }
    
    func loadPlaceNote(for placeId: String) {
        guard let userId = userSession.currentUserId else { return }
        
        userService.fetchPlaceNote(userId: userId, placeId: placeId) { [weak self] placeNote, error in
            DispatchQueue.main.async {
                if let placeNote = placeNote {
                    self?.placeNotes[placeId] = placeNote
                }
            }
        }
    }
    
    func deletePlaceNote(for placeId: String) {
        guard let userId = userSession.currentUserId,
              let placeNote = placeNotes[placeId] else { return }
        
        userService.deletePlaceNote(userId: userId, placeId: placeNote.placeId) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.placeNotes.removeValue(forKey: placeId)
                }
            } else if let error = error {
                print("Error deleting place note: \(error.localizedDescription)")
            }
        }
    }
    
    func getPlaceNote(for placeId: String) -> PlaceNote? {
        return placeNotes[placeId]
    }
    
    // MARK: - TikTok Place Flagging
    
    func flagTikTokPlace(for placeId: String, flagType: TikTokPlaceFlagType, tikTokUrl: String? = nil, userComment: String? = nil) {
        guard let userId = userSession.currentUserId else { return }
        
        let flag = TikTokPlaceFlag(
            placeId: placeId,
            userId: userId,
            flagType: flagType,
            tikTokUrl: tikTokUrl,
            userComment: userComment
        )
        
        userService.saveTikTokPlaceFlag(flag: flag) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.tikTokPlaceFlags[placeId] = flag
                }
            } else if let error = error {
                print("Error saving TikTok place flag: \(error.localizedDescription)")
            }
        }
    }
    
    func loadTikTokPlaceFlag(for placeId: String) {
        guard let userId = userSession.currentUserId else { return }
        
        userService.hasUserFlaggedPlace(userId: userId, placeId: placeId) { [weak self] flag, error in
            DispatchQueue.main.async {
                if let flag = flag {
                    self?.tikTokPlaceFlags[placeId] = flag
                }
            }
        }
    }
    
    func removeTikTokPlaceFlag(for placeId: String) {
        guard let userId = userSession.currentUserId,
              let flag = tikTokPlaceFlags[placeId] else { return }
        
        userService.deleteTikTokPlaceFlag(userId: userId, placeId: placeId) { [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.tikTokPlaceFlags.removeValue(forKey: placeId)
                }
            } else if let error = error {
                print("Error deleting TikTok place flag: \(error.localizedDescription)")
            }
        }
    }
    
    func getTikTokPlaceFlag(for placeId: String) -> TikTokPlaceFlag? {
        return tikTokPlaceFlags[placeId]
    }
    
    func hasFlaggedTikTokPlace(placeId: String) -> Bool {
        return tikTokPlaceFlags[placeId] != nil
    }
    
    func saveExternalPlace(externalPlace: ExternalPlace, completion: @escaping (Bool, Error?) -> Void) {
        guard let userId = userSession.currentUserId else {
            completion(false, NSError(domain: "ProfileViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"]))
            return
        }
        userService.saveExternalPlace(externalPlace: externalPlace, completion: completion)
    }

     func addNewPlaceList(named name: String, city: String, emoji: String, image: String) {
         let newPlaceList = PlaceList(name: name, city: city, emoji: emoji, image: image)
         userLists.append(newPlaceList)
         sortListsByDistance() // Sort lists by distance after adding new list
         guard let userId = userSession.currentUserId else { return }
         placeService.createNewList(userId: userId, listName: newPlaceList.name, city: newPlaceList.city, emoji: newPlaceList.emoji, image: newPlaceList.image ?? "") { [weak self] createdList, error in
             if let error = error {
                 print("❌ Error creating new list: \(error)")
             } else if let createdList = createdList {
                 print("✅ Successfully created new list: \(createdList.name)")
             }
         }
         recentlyCreatedListId = newPlaceList.id
         
         // Clear the recently created list ID after a short delay
         DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
             if self.recentlyCreatedListId == newPlaceList.id {
                 self.recentlyCreatedListId = nil
             }
         }
     }
    
     func removePlaceList(placeList: PlaceList) {
         if let index = userLists.firstIndex(where: { $0.id == placeList.id }) {
             userLists.remove(at: index)
             sortListsByDistance() // Sort lists by distance after removing list
             guard let currentUserId = userSession.currentUserId else { return }
             placeService.deleteList(userId: currentUserId, listId: placeList.id.uuidString) { error in
                 if error != nil {
                     // Re-add the list if deletion failed
                     self.userLists.append(placeList)
                     self.sortListsByDistance()
                 }
                 // No need to sort on success - already sorted above
             }
         }
     }

    
    
     // Returns unique users who saved a place, excluding the current logged-in user
     func getUniquePlaceSaversExcludingCurrentUser(forPlaceId placeId: String) -> [ProfileData] {
         guard let userIds = detailPlaceViewModel.placeSavers[placeId], let currentUserId = user?.id else { return [] }
         
         // Filter out the current user and map to ProfileData in userFollowing
         let uniqueUsers = userIds
             .filter { $0 != currentUserId }
             .compactMap { userId in
                 userFollowing.first(where: { $0.id == userId })
             }
         
         return uniqueUsers
     }
    
     func isPlaceInAnyList(placeId: String) -> Bool {
         return userListsPlaces.values.contains { $0.contains(placeId) }
     }

    /// Returns a dictionary mapping each PlaceList's id to the count of places in that list
    func placeCountsForAllLists() -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for list in userLists {
            counts[list.id] = list.places.count
        }
        return counts
    }

    /// Returns the count of places in the PlaceList with the given id, or 0 if not found
    func placeCount(forListId listId: UUID) -> Int {
        return userLists.first(where: { $0.id == listId })?.places.count ?? 0
    }
    
    func refreshUserPlaces() async {
        // Combine all place IDs from favorites and all lists, then de-duplicate
        var allPlaceIds = Set(userFavorites)
        for list in userListsPlaces.values {
            allPlaceIds.formUnion(list)
        }
        await detailPlaceViewModel.refreshPlaces(detailPlaces: Array(allPlaceIds))
    }

    func loadMyReviewedPlacesWithPagination() {
        guard let userId = user?.id else { return }
        if allReviewedPlaceIds.isEmpty {
            isLoadingReviewedPlaces = true
            Task {
                do {
                    let restaurantReviews: [RestaurantReview] = try await reviewService.fetchUserReviews(userId: userId)
                    let genericReviews: [GenericReview] = try await reviewService.fetchUserGenericReviews(userId: userId)
                    let allReviews: [ReviewProtocol] = restaurantReviews + genericReviews
                    
                    // Sort reviews by timestamp (most recent first) and get unique place IDs while preserving order
                    let sortedReviews = allReviews.sorted { $0.timestamp > $1.timestamp }

                    // Get unique place IDs while preserving the order of most recently reviewed places
                    var seenPlaceIds = Set<String>()
                    allReviewedPlaceIds = sortedReviews.compactMap { review in
                        if seenPlaceIds.contains(review.placeId) {
                            return nil
                        }
                        seenPlaceIds.insert(review.placeId)
                        return review.placeId
                    }
                } catch {
                    isLoadingReviewedPlaces = false
                    return
                }
                if allReviewedPlaceIds.isEmpty {
                    isLoadingReviewedPlaces = false
                    return
                }
                await self.loadNextBatchOfMyReviews()
            }
        } else {
            Task { await self.loadNextBatchOfMyReviews() }
}
    }

    private func loadNextBatchOfMyReviews() async {
        guard !isLoadingMoreReviews && _hasMoreReviews else {
            isLoadingReviewedPlaces = false
            return
        }
        isLoadingMoreReviews = true
        let startIndex = currentReviewPage * reviewsPerPage
        let endIndex = min(startIndex + reviewsPerPage, allReviewedPlaceIds.count)
        guard startIndex < allReviewedPlaceIds.count else {
            _hasMoreReviews = false
            isLoadingMoreReviews = false
            isLoadingReviewedPlaces = false
            return
        }
        let placeIdsToLoad = Array(allReviewedPlaceIds[startIndex..<endIndex])
        var successfullyLoadedPlaceIds: [String] = []
        guard let currentUserId = user?.id else {
            isLoadingMoreReviews = false
            isLoadingReviewedPlaces = false
            return
        }
        
        // Fetch review images for these places in parallel
        await fetchReviewImagesForPlaces(placeIdsToLoad, userId: currentUserId)
        
        for placeId in placeIdsToLoad {
            if detailPlaceViewModel.places[placeId] == nil {
                // Retry logic for failed place loads
                var retryCount = 0
                let maxRetries = 2

                while retryCount <= maxRetries {
                    do {
                        let detailPlace = try await placeService.fetchPlace(withId: placeId)
                        await MainActor.run {
                            detailPlaceViewModel.places[placeId] = detailPlace
                            detailPlaceViewModel.fetchPlaceImage(for: placeId)
                            successfullyLoadedPlaceIds.append(placeId)
                        }
                        break // Success, exit retry loop
                    } catch {
                        retryCount += 1
                        if retryCount <= maxRetries {
                            print("⚠️ [ProfileViewModel] Failed to load place \(placeId), retrying (\(retryCount)/\(maxRetries)): \(error.localizedDescription)")
                            try? await Task.sleep(nanoseconds: 500_000_000 * UInt64(retryCount)) // Exponential backoff
                        } else {
                            print("❌ [ProfileViewModel] Failed to load place \(placeId) after \(maxRetries) retries: \(error.localizedDescription)")
                            // Could add to a failed places list for later retry
                        }
                    }
                }
            } else {
                successfullyLoadedPlaceIds.append(placeId)
            }
            
            // Add current user as saver so reviewed places appear on map with profile picture
            if detailPlaceViewModel.placeSavers[placeId] == nil {
                detailPlaceViewModel.placeSavers[placeId] = [currentUserId]
            } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(currentUserId) {
                detailPlaceViewModel.placeSavers[placeId]!.append(currentUserId)
            }
        }
        
        // Only add new place IDs
        let newPlaceIds = successfullyLoadedPlaceIds.filter { !loadedReviewedPlaceIds.contains($0) }
        loadedReviewedPlaceIds.append(contentsOf: newPlaceIds)
        currentReviewPage += 1
        _hasMoreReviews = endIndex < allReviewedPlaceIds.count
        isLoadingMoreReviews = false
        isLoadingReviewedPlaces = false
        
        // Recalculate map annotations to include new reviewed places
        detailPlaceViewModel.calculateAnnotationPlaces()
    }

    func loadMoreMyReviews() {
        Task { await self.loadNextBatchOfMyReviews() }
    }
    
    /// Fetch review images for a batch of places to enhance the place display
    private func fetchReviewImagesForPlaces(_ placeIds: [String], userId: String) async {
        // Collect all image URLs first
        var imageUrlsToLoad: [(placeId: String, imageUrl: String)] = []
        
        // Fetch reviews for these places to get images
        for placeId in placeIds {
            do {
                // Get the most recent review for this place by this user
                let reviews = try await reviewService.fetchPlaceReviews(placeId: placeId, latestOnly: false)
                let userReviews = reviews.filter { $0.userId == userId }
                
                if let mostRecentReview = userReviews.first(where: { !$0.images.isEmpty }),
                   let imageUrl = mostRecentReview.images.first,
                   detailPlaceViewModel.placeImages[placeId] == nil {
                    imageUrlsToLoad.append((placeId: placeId, imageUrl: imageUrl))
                }
            } catch {
                print("⚠️ [ProfileViewModel] Failed to fetch review images for place \(placeId): \(error.localizedDescription)")
            }
        }
        
        // Load all images in parallel
        if !imageUrlsToLoad.isEmpty {
            // Loading review images in parallel
            await withTaskGroup(of: Void.self) { group in
                for (placeId, imageUrl) in imageUrlsToLoad {
                    group.addTask {
                        await self.loadImageFromURL(imageUrl: imageUrl, placeId: placeId)
                    }
                }
            }
        }
    }

    func getMyReviewedPlaces() -> [DetailPlace] {
        return loadedReviewedPlaceIds.compactMap { detailPlaceViewModel.places[$0] }
    }
    
    /// Load image directly from URL and add to placeImages
    private func loadImageFromURL(imageUrl: String, placeId: String) async {
        // ✅ COMPLETE Firebase elimination - block ALL Firebase URLs, only use Supabase
        if imageUrl.contains("firebasestorage.googleapis.com") {
            print("🚫 [ProfileViewModel] BLOCKING Firebase Storage URL - Firebase migration complete, use Supabase only: \(imageUrl)")
            return
        }
        
        guard let url = URL(string: imageUrl) else {
            print("⚠️ [ProfileViewModel] Invalid image URL: \(imageUrl)")
            return
        }
        
        do {
            // Use a more efficient URLSession configuration for image loading
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0  // ✅ Reduced timeout
            config.timeoutIntervalForResource = 10.0  // ✅ Reduced timeout
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    detailPlaceViewModel.placeImages[placeId] = image
                    // Loaded review image for place
                }
            } else {
                print("⚠️ [ProfileViewModel] Failed to create UIImage from data for place \(placeId)")
            }
        } catch {
            print("⚠️ [ProfileViewModel] Failed to load image from URL for place \(placeId): \(error.localizedDescription)")
        }
    }

    func resetMyReviewedPlacesPagination() {
        isLoadingReviewedPlaces = false
        isLoadingMoreReviews = false
        _hasMoreReviews = true
        currentReviewPage = 0
        allReviewedPlaceIds = []
        loadedReviewedPlaceIds = []
    }

    var hasMoreReviews: Bool { _hasMoreReviews }
    
    /// Get the total count of reviewed places
    var reviewedPlacesCount: Int {
        return allReviewedPlaceIds.count
    }
    
    // User reviews for display in My Places
    @Published var userReviews: [ReviewProtocol] = []
    @Published var isLoadingUserReviews: Bool = false
    
    /// Load the last 8 reviews made by the user
    func loadUserReviews() async {
        guard let userId = user?.id else { return }
        
        await MainActor.run {
            isLoadingUserReviews = true
        }
        
        do {
            // Fetch both restaurant and generic reviews
            async let restaurantReviews: [RestaurantReview] = try await reviewService.fetchUserReviews(userId: userId)
            async let genericReviews: [GenericReview] = try await reviewService.fetchUserGenericReviews(userId: userId)
            
            let allReviews: [ReviewProtocol] = (try await restaurantReviews) + (try await genericReviews)
            
            // Sort by timestamp (most recent first) and take the last 8
            let sortedReviews = allReviews.sorted { $0.timestamp > $1.timestamp }
            let last8Reviews = Array(sortedReviews.prefix(8))
            
            await MainActor.run {
                userReviews = last8Reviews
                isLoadingUserReviews = false
            }
        } catch {
            print("❌ [ProfileViewModel] Error loading user reviews: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingUserReviews = false
            }
        }
    }
    
    // MARK: - TikTok Places Refresh After Import
    
    /// Refresh TikTok places list after a successful import
    func refreshTikTokPlacesAfterImport() {
        print("🔄 [ProfileViewModel] Refreshing TikTok places after import...")
        
        // Clear lightweight external places to trigger reload
        lightweightExternalPlaces = []
        
        // The TikTok tab will auto-reload when user navigates to it next time
        print("✅ [ProfileViewModel] TikTok places will reload when tab is opened")
    }
    
    // MARK: - TikTok Place Deletion
    
    func deleteTikTokPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        guard let userId = user?.id else {
            completion(false)
            return
        }
        
        let placeId = place.id.uuidString
        
        // Remove from local state first (optimistic update)
        if let index = allTikTokPlaceIds.firstIndex(of: placeId) {
            allTikTokPlaceIds.remove(at: index)
        }
        if let index = loadedTikTokPlaceIds.firstIndex(of: placeId) {
            loadedTikTokPlaceIds.remove(at: index)
        }
        
        // Remove from userExternalPlaces
        userExternalPlaces.removeValue(forKey: placeId)
        
        // Remove from placeSavers (so it doesn't appear on map)
        if var savers = detailPlaceViewModel.placeSavers[placeId] {
            savers.removeAll { $0 == userId }
            if savers.isEmpty {
                detailPlaceViewModel.placeSavers.removeValue(forKey: placeId)
            } else {
                detailPlaceViewModel.placeSavers[placeId] = savers
            }
        }
        
        // Remove from places dictionary
        detailPlaceViewModel.places.removeValue(forKey: placeId)
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
        
        // Call backend to delete the TikTok place
        userService.deleteTikTokPlace(userId: userId, placeId: placeId) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileViewModel] Error deleting TikTok place: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ [ProfileViewModel] Successfully deleted TikTok place: \(place.name)")
                    completion(true)
                }
            }
        }
    }
    
    private func revertTikTokPlaceDeletion(_ place: DetailPlace) {
        let placeId = place.id.uuidString
        
        // Re-add to local state
        if !allTikTokPlaceIds.contains(placeId) {
            allTikTokPlaceIds.append(placeId)
            allTikTokPlaceIds.sort { placeId1, placeId2 in
                // Sort by date (most recent first)
                let place1 = userExternalPlaces[placeId1]
                let place2 = userExternalPlaces[placeId2]
                return (place1?.addedAt ?? Date.distantPast) > (place2?.addedAt ?? Date.distantPast)
            }
        }
        
        if !loadedTikTokPlaceIds.contains(placeId) {
            loadedTikTokPlaceIds.append(placeId)
        }
        
        // Re-add to placeSavers
        if let userId = user?.id {
            if detailPlaceViewModel.placeSavers[placeId] == nil {
                detailPlaceViewModel.placeSavers[placeId] = [userId]
            } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                detailPlaceViewModel.placeSavers[placeId]!.append(userId)
            }
        }
        
        // Re-add to places dictionary
        detailPlaceViewModel.places[placeId] = place
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
    }
    
    // MARK: - Reviewed Places Access
    
    /// Check if the current user has reviewed a specific place
    func hasReviewedPlace(placeId: String) -> Bool {
        return allReviewedPlaceIds.contains(placeId)
    }
    
    // MARK: - List Sorting by Distance
    
    private var hasPerformedInitialSort = false
    
    /// Calculates the distance from the user's current location to a list using pre-calculated average coordinates
    private func calculateDistanceToList(_ list: PlaceList) -> Double {
        guard let currentLocation = locationManager.currentLocation else { 
            return Double.infinity 
        }
        
        // Use pre-calculated average coordinates if available (much faster!)
        if let averageCoordinate = list.averageCoordinate {
            let listLocation = CLLocation(
                latitude: averageCoordinate.latitude,
                longitude: averageCoordinate.longitude
            )
            let distance = currentLocation.distance(from: listLocation)
            return distance
        }
        
        // Fallback to calculating average distance from individual places (slower)
        let listPlaceIds = userListsPlaces[list.id.uuidString] ?? []
        guard !listPlaceIds.isEmpty else { return Double.infinity }
        
        var totalDistance: Double = 0
        var validPlaceCount: Int = 0
        
        for placeId in listPlaceIds {
            if let detailPlace = detailPlaceViewModel.places[placeId] {
                if let placeCoordinate = detailPlace.coordinate {
                    let placeLocation = CLLocation(
                        latitude: placeCoordinate.latitude,
                        longitude: placeCoordinate.longitude
                    )
                    
                    let distance = currentLocation.distance(from: placeLocation)
                    totalDistance += distance
                    validPlaceCount += 1
                } else {
                }
            } else {
            }
        }
        
        let averageDistance = validPlaceCount > 0 ? totalDistance / Double(validPlaceCount) : Double.infinity
        
        return averageDistance
    }
    
    /// Recalculates the average coordinates for a specific list
    private func recalculateAverageCoordinates(for listId: UUID) {
        guard let listIndex = userLists.firstIndex(where: { $0.id == listId }),
              let placeIds = userListsPlaces[listId.uuidString] else {
            return
        }
        
        var totalLatitude: Double = 0
        var totalLongitude: Double = 0
        var validPlaceCount: Int = 0
        
        // Calculate average from all places in the list
        for placeId in placeIds {
            if let detailPlace = detailPlaceViewModel.places[placeId],
               let coordinate = detailPlace.coordinate {
                totalLatitude += coordinate.latitude
                totalLongitude += coordinate.longitude
                validPlaceCount += 1
            }
        }
        
        // Update the list's average coordinates
        if validPlaceCount > 0 {
            let averageLatitude = totalLatitude / Double(validPlaceCount)
            let averageLongitude = totalLongitude / Double(validPlaceCount)
            
            userLists[listIndex].averageCoordinate = CLLocationCoordinate2D(
                latitude: averageLatitude,
                longitude: averageLongitude
            )
            userLists[listIndex].lastCoordinateUpdate = Date()
            
            
            // Update in Firestore
            if let userId = userSession.currentUserId {
                Task {
                    await updateListAverageCoordinates(userId: userId, listId: listId, averageCoordinate: userLists[listIndex].averageCoordinate!)
                }
            }
        } else {
            // No valid coordinates, clear the average
            userLists[listIndex].averageCoordinate = nil
            userLists[listIndex].lastCoordinateUpdate = Date()
        }
    }
    
    /// Updates the average coordinates in Supabase
    private func updateListAverageCoordinates(userId: String, listId: UUID, averageCoordinate: CLLocationCoordinate2D) async {
        // TODO: Implement with Supabase
        // Previously used Firestore to update place list average coordinates
        // Need to implement equivalent Supabase update
        print("⚠️ updateListAverageCoordinates not yet implemented for Supabase")
    }
    
    /// Sorts userLists by their distance from the user's current location (closest first)
    /// Now uses pre-calculated average coordinates for much faster sorting
    func sortListsByDistance() {
        guard locationManager.currentLocation != nil else { 
            print("📍 [ProfileViewModel] sortListsByDistance: No location available, skipping sort")
            return 
        }
        
        
        userLists.sort { list1, list2 in
            let distance1 = calculateDistanceToList(list1)
            let distance2 = calculateDistanceToList(list2)
            
            // If both lists have valid distances, sort by distance
            if distance1 != Double.infinity && distance2 != Double.infinity {
                return distance1 < distance2
            }
            // If only one has valid distance, prioritize it
            else if distance1 != Double.infinity {
                return true
            }
            else if distance2 != Double.infinity {
                return false
            }
            // If neither has valid distance, sort alphabetically
            else {
                return list1.name < list2.name
            }
        }
        
        hasPerformedInitialSort = true
    }

    /// Public method for manual refresh (if needed) - should only be called by user actions like pull-to-refresh
    func refreshListSorting() {
        sortListsByDistance()
    }
    
    /// Returns whether the initial sort has been performed
    var hasCompletedInitialSort: Bool {
        hasPerformedInitialSort
    }
    
    // MARK: - TikTok Processing
    
    func processSharedTikTokURL(_ urlString: String, 
                               tikTokService: TikTokService,
                               selectedPlaceVM: SelectedPlaceViewModel,
                               placeVM: DetailPlaceViewModel) async -> Bool {
        
        // Check if this URL was recently processed
        if recentlyProcessedURLs.contains(urlString) {
            print("⚠️ [ProfileViewModel] URL already processed recently, skipping: \(urlString)")
            return false
        }
        
        // Check if already processing
        if isProcessingTikTok {
            print("⚠️ [ProfileViewModel] Already processing a TikTok URL, skipping: \(urlString)")
            return false
        }
        
        // Mark as processing and add to recently processed
        await MainActor.run {
            isProcessingTikTok = true
            recentlyProcessedURLs.insert(urlString)
        }
        
        let result = await tikTokService.processTikTokURL(urlString)
        
        // Don't set isProcessingTikTok = false here - let it persist until place detail is ready
        // The loading screen will be dismissed when placeDetailViewReady() is called
        
        // Clear from recently processed after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            self.recentlyProcessedURLs.remove(urlString)
        }
        
        switch result {
        case .success(let detailPlaces):
            print("✅ [ProfileViewModel] Successfully processed TikTok URL, received \(detailPlaces.count) place(s)")
            
            // Clear any previous errors
            tikTokImportError = nil
            
            Task { @MainActor in
                if detailPlaces.count == 1 {
                    // Single place - show detail directly
                    let detailPlace = detailPlaces[0]
                    
                    // Validate place has a name
                    if detailPlace.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("❌ [ProfileViewModel] Single place found but has no name")
                        noPlacesFoundTikTokUrl = urlString
                        isShowingNoPlacesFound = true
                        isProcessingTikTok = false
                        deepLinkManager?.isProcessingDeepLink = false
                        return
                    }
                    placeVM.places[detailPlace.id.uuidString] = detailPlace
                    // Add current user as saver so pin shows with profile
                    if let uid = await SupabaseAuthService.shared.currentUserId {
                        placeVM.placeSavers[detailPlace.id.uuidString] = [uid]
                    }
                    placeVM.calculateAnnotationPlaces()
                    selectedPlaceVM.selectedPlace = detailPlace
                    selectedPlaceVM.isDetailSheetPresented = true
                    
                    // Set waiting state to keep loading screen until place detail is ready
                    isWaitingForPlaceDetail = true
                    print("⏳ [ProfileViewModel] Set isWaitingForPlaceDetail = true, waiting for DetailPlaceView to load...")
                    
                    // Refresh TikTok places list after successful import
                    refreshTikTokPlacesAfterImport()
                    
                    // Don't clear isWaitingForPlaceDetail here - let the DetailPlaceView control when it's ready
                    // The DetailPlaceView will call placeDetailViewReady() when fully loaded
                
                } else if detailPlaces.count > 1 {
                    // Multiple places - show selection screen
                    print("🎯 [ProfileViewModel] MULTIPLE PLACES DETECTED: \(detailPlaces.count) places - SHOULD SHOW SELECTION SCREEN")
                    
                    // Validate all places have names
                    let validPlaces = detailPlaces.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    
                    print("🔍 [ProfileViewModel] Valid places after filtering: \(validPlaces.count)")
                    for place in validPlaces {
                        print("   ✓ \(place.name)")
                    }
                    
                    if validPlaces.isEmpty {
                        print("❌ [ProfileViewModel] No valid places found after filtering")
                        noPlacesFoundTikTokUrl = urlString
                        isShowingNoPlacesFound = true
                        isProcessingTikTok = false
                        deepLinkManager?.isProcessingDeepLink = false
                        return
                    }
                    
                    // Add all valid places to place manager
                    for place in validPlaces {
                        placeVM.places[place.id.uuidString] = place
                    }
                    
                    importedPlaces = validPlaces
                    isShowingPlaceSelection = true
                    print("🎯 [ProfileViewModel] Set isShowingPlaceSelection = true, importedPlaces count = \(validPlaces.count)")
                    
                    // Refresh TikTok places list after successful import (even for multiple places)
                    refreshTikTokPlacesAfterImport()
                } else {
                    // No places found - show flagging interface
                    print("❌ [ProfileViewModel] No places found: count = \(detailPlaces.count)")
                    noPlacesFoundTikTokUrl = urlString
                    isShowingNoPlacesFound = true
                    isProcessingTikTok = false
                    isWaitingForPlaceDetail = false  // Ensure waiting state is also cleared
                    deepLinkManager?.isProcessingDeepLink = false
                    deepLinkViewModel?.isProcessingDeepLink = false  // Direct update to ensure sync
                    print("✅ [ProfileViewModel] Cleared all loading states for no places found")
                    print("   - isProcessingTikTok: \(isProcessingTikTok)")
                    print("   - isWaitingForPlaceDetail: \(isWaitingForPlaceDetail)")
                    print("   - deepLinkManager?.isProcessingDeepLink: \(deepLinkManager?.isProcessingDeepLink ?? false)")
                    print("   - deepLinkViewModel?.isProcessingDeepLink: \(deepLinkViewModel?.isProcessingDeepLink ?? false)")
                }
            }
            
            
            if detailPlaces.count == 1 {
                print("⏳ [ProfileViewModel] Adding delay to ensure DetailPlaceView has time to start loading...")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                print("⏳ [ProfileViewModel] Delay completed, TikTok processing will now finish")
            }
            
            // NOTE: Place saving is handled by backend during URL processing
            return true
            
        case .failure(let error):
            print("❌ [ProfileViewModel] TikTok processing failed: \(error.localizedDescription)")
            
            await MainActor.run {
                // Set user-friendly error message based on error type
                if error.localizedDescription.contains("network") || error.localizedDescription.contains("Internet") {
                    tikTokImportError = "Please check your internet connection and try again"
                } else if error.localizedDescription.contains("invalid") || error.localizedDescription.contains("URL") {
                    tikTokImportError = "This doesn't appear to be a valid TikTok URL"
                } else {
                    tikTokImportError = "We couldn't find any places in this TikTok video. Try sharing a different video that shows specific locations"
                }
                isProcessingTikTok = false
                deepLinkManager?.isProcessingDeepLink = false
            }
            
            return false
        }
    }
    
    // NOTE: Place saving is handled by backend during URL processing
    // Frontend does not save to Firestore - removed saveTikTokPlaceToFirestore method
    
    /// Called when the place detail view is fully loaded and ready
    func placeDetailViewReady() {
        print("✅ [ProfileViewModel] DetailPlaceView is fully loaded, clearing waiting state")
        isWaitingForPlaceDetail = false
        isProcessingTikTok = false
        deepLinkManager?.isProcessingDeepLink = false
    }
    
    /// Clear TikTok import error
    func clearTikTokImportError() {
        tikTokImportError = nil
    }
    
    /// Clear place selection state
    func clearPlaceSelection() {
        importedPlaces = []
        isShowingPlaceSelection = false
        
        // Refresh TikTok places list after clearing selection (in case places were added to lists)
        refreshTikTokPlacesAfterImport()
    }
    
    /// Clear no places found state
    func clearNoPlacesFound() {
        isShowingNoPlacesFound = false
        noPlacesFoundTikTokUrl = ""
        // Ensure processing states are cleared when user closes the view
        isProcessingTikTok = false
        isWaitingForPlaceDetail = false
        deepLinkManager?.isProcessingDeepLink = false
        deepLinkViewModel?.isProcessingDeepLink = false  // Direct update to ensure sync
        print("✅ [ProfileViewModel] clearNoPlacesFound: Cleared all processing states")
    }
    
    func placeSelectionViewAppeared() {
        isWaitingForPlaceDetail = false
        isProcessingTikTok = false
        deepLinkManager?.isProcessingDeepLink = false
        deepLinkViewModel?.isProcessingDeepLink = false  // Direct update to ensure sync
    }
    
    func ensureListsLoaded() {
        guard let userId = user?.id else { 
            print("🔍 [ProfileViewModel] ensureListsLoaded: No user ID")
            return 
        }
        
        // Check if we need to load places for the first 3 lists
        let firstThreeLists = Array(userLists.prefix(3))
        let needsPlaceLoading = firstThreeLists.contains { list in
            userListsPlaces[list.id.uuidString]?.isEmpty != false
        }
        
        if !needsPlaceLoading {
            print("🔍 [ProfileViewModel] ensureListsLoaded: First 3 lists already have places loaded")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        print("🔍 [ProfileViewModel] ensureListsLoaded: Loading places for first 3 lists")
        
        // Indicate loading state so UI can show a spinner
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        Task {
            do {
                // Use the existing lists (already loaded by DataManager)
                let lists = self.userLists
                print("🔍 [ProfileViewModel] ensureListsLoaded: Using existing \(lists.count) lists")
                
                // Load places and counts for the first 3 visible lists
                let firstThreeListIds = Array(lists.prefix(3).map { $0.id.uuidString })
                print("🔍 [ProfileViewModel] First 3 list IDs: \(firstThreeListIds)")
                
                if !firstThreeListIds.isEmpty {
                    print("🔍 [ProfileViewModel] Fetching places for first 3 lists...")
                    // Fetch places for first 3 lists (6 places each)
                    let placesForLists = try await placeService.fetchPlacesForLists(listIds: firstThreeListIds, maxPlacesPerList: 6)
                    print("🔍 [ProfileViewModel] Received places for \(placesForLists.count) lists")
                    
                    // Fetch place counts for all lists
                    let placeCounts = try await placeService.getPlaceCountsForLists(listIds: lists.map { $0.id.uuidString })
                    
                    await MainActor.run {
                        // Update places for first 3 lists
                        for (listId, places) in placesForLists {
                            let placeIds = places.map { $0.id.uuidString }
                            self.userListsPlaces[listId] = placeIds
                            
                            // Store places in detailPlaceViewModel for immediate access
                            for place in places {
                                self.detailPlaceViewModel.places[place.id.uuidString] = place
                            }
                            
                            // Load images for these places
                            for place in places {
                                self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                            }
                            
                            // Mark as loaded
                            if let uuid = UUID(uuidString: listId) {
                                self.loadedListIds.insert(uuid)
                            }
                        }
                        
                        // Store place counts for all lists (for display)
                        for (listId, count) in placeCounts {
                            if let uuid = UUID(uuidString: listId) {
                                self.placeListCounts[uuid] = count
                            }
                        }
                        
                        print("🔍 [ProfileViewModel] ensureListsLoaded: Updated userListsPlaces with \(self.userListsPlaces.count) entries")
                        print("🔍 [ProfileViewModel] ensureListsLoaded: Loaded places for first \(placesForLists.count) lists")
                        
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
                
            } catch {
                print("❌ [ProfileViewModel] ensureListsLoaded: Error loading places for lists: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Bulk calculates average coordinates for all lists that don't have them
    /// This is much faster than calculating them one by one
    private func bulkCalculateAverageCoordinates() {
        print("🚀 [ProfileViewModel] Bulk calculating average coordinates for all lists")
        
        // Group lists by whether they need calculation
        let listsNeedingCalculation = userLists.filter { $0.averageCoordinate == nil }
        let listsWithCoordinates = userLists.filter { $0.averageCoordinate != nil }
        
        print("🚀 [ProfileViewModel] \(listsWithCoordinates.count) lists already have coordinates, \(listsNeedingCalculation.count) need calculation")
        
        if listsNeedingCalculation.isEmpty {
            print("🚀 [ProfileViewModel] All lists already have average coordinates - fast sorting ready!")
            return
        }
        
        // Calculate for all lists that need it
        for list in listsNeedingCalculation {
            recalculateAverageCoordinates(for: list.id)
        }
        
        print("🚀 [ProfileViewModel] Bulk calculation complete - all lists now have average coordinates")
    }
    
    func loadListDataIfNeeded(listId: UUID) {
        guard !loadedListIds.contains(listId) && !loadingListIds.contains(listId),
              let userId = user?.id else {
            print("🔍 [ProfileViewModel] loadListDataIfNeeded: List \(listId) already loaded or loading")
            return
        }

        // Check if we're at the concurrency limit
        if activeListLoadTasks.count >= maxConcurrentListLoads {
            print("🔍 [ProfileViewModel] loadListDataIfNeeded: At concurrency limit (\(maxConcurrentListLoads)), queuing list \(listId)")
            // Queue the task for later execution
            let task = Task {
                // Wait for a slot to become available
                while activeListLoadTasks.count >= maxConcurrentListLoads {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    if Task.isCancelled { return }
                }
                await self.performListLoad(listId: listId, userId: userId)
            }
            activeListLoadTasks[listId] = task
            return
        }

        // Execute immediately if under the limit
        let task = Task {
            await self.performListLoad(listId: listId, userId: userId)
        }
        activeListLoadTasks[listId] = task
    }

    private func performListLoad(listId: UUID, userId: String) async {
        print("🔍 [ProfileViewModel] performListLoad: Loading data for list \(listId)")
        
        // Check if places are already loaded (e.g., from preloading)
        let alreadyLoaded = await MainActor.run {
            let listIdString = listId.uuidString
            let hasPlaceIds = userListsPlaces[listIdString]?.isEmpty == false
            let hasDetailPlaces = userListsPlaces[listIdString]?.allSatisfy { placeId in
                detailPlaceViewModel.places[placeId] != nil
            } ?? false
            return hasPlaceIds && hasDetailPlaces
        }
        
        if alreadyLoaded {
            print("✅ [ProfileViewModel] performListLoad: Places already loaded for list \(listId), skipping")
            await MainActor.run {
                self.loadedListIds.insert(listId)
                self.initializeListPagination(listId: listId)
            }
            return
        }
        
        await MainActor.run {
            self.loadingListIds.insert(listId)
        }

        // Use the optimized method to load places for this list
        do {
            let placesForLists = try await placeService.fetchPlacesForLists(
                listIds: [listId.uuidString], 
                maxPlacesPerList: 50 // Load more places when list is opened
            )
            
            if let places = placesForLists[listId.uuidString] {
                await MainActor.run {
                    let placeIds = places.map { $0.id.uuidString }
                    self.userListsPlaces[listId.uuidString] = placeIds
                    
                    // Store places in detailPlaceViewModel for immediate access
                    for place in places {
                        self.detailPlaceViewModel.places[place.id.uuidString] = place
                    }
                    
                            // Load images for these places
                            for place in places {
                                self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                            }
                    
                    self.loadedListIds.insert(listId)
                    self.loadingListIds.remove(listId)
                    self.activeListLoadTasks.removeValue(forKey: listId)

                    // Initialize pagination for this list
                    self.initializeListPagination(listId: listId)

                    print("✅ [ProfileViewModel] performListLoad: Successfully loaded \(places.count) places for list \(listId)")
                }
            }
        } catch {
            print("❌ [ProfileViewModel] performListLoad: Error loading places for list \(listId): \(error)")
            await MainActor.run {
                self.loadingListIds.remove(listId)
                self.activeListLoadTasks.removeValue(forKey: listId)
            }
        }
    }
    
    /// Load more lists when user scrolls (lazy loading)
    func loadMoreListsIfNeeded() {
        // Find the next 3 lists that haven't been loaded yet
        let unloadedLists = userLists.filter { !loadedListIds.contains($0.id) && !loadingListIds.contains($0.id) }
        let nextThreeLists = Array(unloadedLists.prefix(3))
        
        guard !nextThreeLists.isEmpty else { return }
        
        let listIds = nextThreeLists.map { $0.id.uuidString }
        
        Task {
            do {
                // Mark as loading
                await MainActor.run {
                    for list in nextThreeLists {
                        self.loadingListIds.insert(list.id)
                    }
                }
                
                // Fetch places for these lists
                let placesForLists = try await placeService.fetchPlacesForLists(listIds: listIds, maxPlacesPerList: 6)
                
                await MainActor.run {
                    // Update places for these lists
                    for (listId, places) in placesForLists {
                        let placeIds = places.map { $0.id.uuidString }
                        self.userListsPlaces[listId] = placeIds
                        
                        // Store places in detailPlaceViewModel for immediate access
                        for place in places {
                            self.detailPlaceViewModel.places[place.id.uuidString] = place
                        }
                        
                            // Load images for these places
                            for place in places {
                                self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                            }
                        
                        // Mark as loaded
                        if let uuid = UUID(uuidString: listId) {
                            self.loadedListIds.insert(uuid)
                            self.loadingListIds.remove(uuid)
                        }
                    }
                    
                    print("🔍 [ProfileViewModel] loadMoreListsIfNeeded: Loaded \(placesForLists.count) more lists")
                }
            } catch {
                print("❌ [ProfileViewModel] loadMoreListsIfNeeded: Error loading more lists: \(error)")
                await MainActor.run {
                    for list in nextThreeLists {
                        self.loadingListIds.remove(list.id)
                    }
                }
            }
        }
    }
    
    // MARK: - List Place Pagination Methods
    
    /// Initialize pagination state for a list
    private func initializeListPagination(listId: UUID) {
        let listIdString = listId.uuidString
        guard let allPlaceIds = userListsPlaces[listIdString], !allPlaceIds.isEmpty else {
            print("🔍 [ProfileViewModel] initializeListPagination: No places found for list \(listId)")
            return
        }
        
        // Initialize pagination state
        var pagination = ListPlacePagination()
        pagination.allPlaceIds = allPlaceIds
        pagination.hasMorePlaces = allPlaceIds.count > pagination.placesPerPage
        
        // Load first page
        loadNextPageForList(listId: listId)
        
        listPlacePagination[listIdString] = pagination
        print("🔍 [ProfileViewModel] initializeListPagination: Initialized pagination for list \(listId) with \(allPlaceIds.count) total places")
        
        // Trigger image preloading for initial places
        preloadImagesForVisiblePlaces(listId: listId)
    }
    
    /// Public method to initialize pagination if needed (called from views)
    func initializeListPaginationIfNeeded(listId: UUID) {
        let listIdString = listId.uuidString
        let allPlaceIds = userListsPlaces[listIdString] ?? []
        print("🔍 [ProfileViewModel] initializeListPaginationIfNeeded: List \(listId) has \(allPlaceIds.count) places")
        
        // Only initialize if not already initialized
        if listPlacePagination[listIdString] == nil {
            print("🔍 [ProfileViewModel] initializeListPaginationIfNeeded: Initializing pagination for list \(listId)")
            initializeListPagination(listId: listId)
        } else {
            print("🔍 [ProfileViewModel] initializeListPaginationIfNeeded: Pagination already exists for list \(listId)")
        }
    }
    
    /// Load the next page of places for a specific list
    func loadNextPageForList(listId: UUID) {
        let listIdString = listId.uuidString
        guard var pagination = listPlacePagination[listIdString],
              !pagination.isLoadingMore,
              pagination.hasMorePlaces else {
            print("🔍 [ProfileViewModel] loadNextPageForList: Cannot load more places for list \(listId)")
            return
        }
        
        pagination.isLoadingMore = true
        listPlacePagination[listIdString] = pagination
        
        let startIndex = pagination.currentPage * pagination.placesPerPage
        let endIndex = min(startIndex + pagination.placesPerPage, pagination.allPlaceIds.count)
        
        guard startIndex < pagination.allPlaceIds.count else {
            pagination.isLoadingMore = false
            pagination.hasMorePlaces = false
            listPlacePagination[listIdString] = pagination
            return
        }
        
        let placeIdsToLoad = Array(pagination.allPlaceIds[startIndex..<endIndex])
        print("🔍 [ProfileViewModel] loadNextPageForList: Loading places \(startIndex) to \(endIndex-1) for list \(listId)")
        
        Task {
            // Load place details for the new place IDs
            for placeId in placeIdsToLoad {
                if detailPlaceViewModel.places[placeId] == nil {
                    do {
                        let detailPlace = try await placeService.fetchPlace(withId: placeId)
                        detailPlaceViewModel.places[placeId] = detailPlace
                        detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    } catch {
                        print("❌ [ProfileViewModel] loadNextPageForList: Failed to load place \(placeId): \(error.localizedDescription)")
                    }
                }
            }
            
            await MainActor.run {
                // Update pagination state
                if var updatedPagination = self.listPlacePagination[listIdString] {
                    updatedPagination.loadedPlaceIds.append(contentsOf: placeIdsToLoad)
                    updatedPagination.currentPage += 1
                    updatedPagination.isLoadingMore = false
                    updatedPagination.hasMorePlaces = endIndex < updatedPagination.allPlaceIds.count
                    
                    self.listPlacePagination[listIdString] = updatedPagination
                    
                    print("✅ [ProfileViewModel] loadNextPageForList: Loaded \(placeIdsToLoad.count) more places for list \(listId). Total loaded: \(updatedPagination.loadedCount)/\(updatedPagination.totalPlaces)")
                    
                    // Trigger image preloading for newly loaded places
                    self.preloadImagesForVisiblePlaces(listId: listId)
                }
            }
        }
    }
    
    /// Get the displayed place IDs for a list (respecting pagination)
    func getDisplayedPlaceIds(for listId: UUID) -> [String] {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.displayedPlaceIds ?? []
    }
    
    /// Check if a list has more places to load
    func hasMorePlaces(for listId: UUID) -> Bool {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.hasMorePlaces ?? false
    }
    
    /// Check if a list is currently loading more places
    func isLoadingMorePlaces(for listId: UUID) -> Bool {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.isLoadingMore ?? false
    }
    
    /// Get the total number of places in a list
    func getTotalPlaceCount(for listId: UUID) -> Int {
        let listIdString = listId.uuidString
        return listPlacePagination[listIdString]?.totalPlaces ?? 0
    }
    
    /// Reset pagination for a list (call when places are added/removed)
    func resetListPagination(listId: UUID) {
        let listIdString = listId.uuidString
        listPlacePagination.removeValue(forKey: listIdString)
        
        // Re-initialize pagination if the list has places
        if let placeIds = userListsPlaces[listIdString], !placeIds.isEmpty {
            initializeListPagination(listId: listId)
        }
    }
    
    /// Smart image preloading for visible places (simplified)
    func preloadImagesForVisiblePlaces(listId: UUID) {
        let displayedPlaceIds = getDisplayedPlaceIds(for: listId)
        
        // Simple preloading without complex async - just mark as ready
        for placeId in displayedPlaceIds {
            if let place = detailPlaceViewModel.places[placeId] {
                // Preload TikTok thumbnails
                if let tikTokVideos = place.tikTokVideos,
                   let firstVideo = tikTokVideos.first,
                   !firstVideo.thumbnailURL.isEmpty {
                    preloadedImages[firstVideo.thumbnailURL] = true
                }
                
                // Note: DetailPlace doesn't have reviews property, so skipping review image preloading
            }
        }
    }
    
    private func handleMultiplePlaces(_ places: [DetailPlace]) {
        print("🎯 [ProfileViewModel] Received \(places.count) places from DeepLinkManager")
        for place in places {
            print("   - \(place.name) (ID: \(place.id))")
        }
        
        importedPlaces = places
        isShowingPlaceSelection = true
        // Keep isWaitingForPlaceDetail = true until the sheet actually appears
        
        print("🎯 [ProfileViewModel] Set isShowingPlaceSelection = true")
    }
    

    
    // MARK: - Place Conversion
    
    func convertToDetailPlace(_ nearbyPlace: NearbyPlaceFeature) -> DetailPlace {
        var detailPlace = DetailPlace()
        detailPlace.id = createConsistentUUID(from: nearbyPlace.properties.actualId)
        detailPlace.name = nearbyPlace.properties.name
        detailPlace.address = nearbyPlace.properties.address
        detailPlace.coordinate = CLLocationCoordinate2D(
            latitude: nearbyPlace.geometry.latitude,
            longitude: nearbyPlace.geometry.longitude
        )
        detailPlace.rating = nearbyPlace.properties.rating
        detailPlace.categories = nearbyPlace.properties.types
        detailPlace.phone = nearbyPlace.properties.photoReference
        return detailPlace
    }
    
    private func createConsistentUUID(from string: String) -> UUID {
        if let uuid = UUID(uuidString: string) {
            return uuid
        }
        
        let hash = abs(string.hashValue)
        let uuidString = String(format: "%08x-0000-0000-0000-%012x", hash, hash)
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    // MARK: - User Actions
    
    func logout() {
        userSession.logout()
    }
    
    func handleTikTokNotification(url: String, 
                                 tikTokService: TikTokService,
                                 selectedPlaceVM: SelectedPlaceViewModel,
                                 placeVM: DetailPlaceViewModel) {
        Task {
            await processSharedTikTokURL(url, 
                                       tikTokService: tikTokService,
                                       selectedPlaceVM: selectedPlaceVM,
                                       placeVM: placeVM)
        }
    }
    
    func checkPendingTikTokURL(tikTokService: TikTokService,
                              selectedPlaceVM: SelectedPlaceViewModel,
                              placeVM: DetailPlaceViewModel) {
        if let pendingURL = UserDefaults.standard.string(forKey: "pendingTikTokURL") {
            Task {
                await processSharedTikTokURL(pendingURL,
                                           tikTokService: tikTokService,
                                           selectedPlaceVM: selectedPlaceVM,
                                           placeVM: placeVM)
            }
            UserDefaults.standard.removeObject(forKey: "pendingTikTokURL")
        }
    }
    
    /// Formats distance for display (meters to miles/kilometers)
    private func formatDistance(_ distanceInMeters: Double) -> String {
        if distanceInMeters == Double.infinity {
            return "Unknown"
        }
        
        let miles = distanceInMeters * 0.000621371 // Convert meters to miles
        if miles < 1 {
            let feet = distanceInMeters * 3.28084 // Convert meters to feet
            return String(format: "%.0f ft", feet)
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
    
    /// Returns the formatted average distance for a list
    func getAverageDistanceForList(_ list: PlaceList) -> String {
        let distance = calculateDistanceToList(list)
        return formatDistance(distance)
    }

    /// Returns true if location is available for distance calculations
    var isLocationAvailable: Bool {
        return locationManager.currentLocation != nil
    }
    
    // MARK: - Place-Specific List Sorting
    
    /// Calculates the average distance of all places in a list from a specific place
    /// FAST VERSION: Uses pre-calculated average coordinates when available
    func calculateAverageDistanceForListFromPlace(_ list: PlaceList, place: DetailPlace) -> Double {
        guard let placeCoordinate = place.coordinate else { 
            print("⚠️ [ProfileViewModel] Place '\(place.name)' has no coordinate, returning infinity")
            return Double.infinity 
        }
        
        // FAST PATH: Use pre-calculated average coordinates if available (much faster!)
        if let averageCoordinate = list.averageCoordinate {
            let targetLocation = CLLocation(
                latitude: placeCoordinate.latitude,
                longitude: placeCoordinate.longitude
            )
            let listLocation = CLLocation(
                latitude: averageCoordinate.latitude,
                longitude: averageCoordinate.longitude
            )
            
            let distance = targetLocation.distance(from: listLocation)
            print("🚀 [ProfileViewModel] FAST: List '\(list.name)' using pre-calculated average coordinates, distance: \(String(format: "%.1f km", distance/1000))")
            return distance
        }
        
        // SLOW PATH: Fallback to calculating from individual places (only if no average coordinate)
        let listPlaceIds = userListsPlaces[list.id.uuidString] ?? []
        guard !listPlaceIds.isEmpty else { 
            print("⚠️ [ProfileViewModel] List '\(list.name)' has no places, returning infinity")
            return Double.infinity 
        }
        
        print("🐌 [ProfileViewModel] SLOW: Calculating distance for list '\(list.name)' with \(listPlaceIds.count) places (no average coordinate)")
        
        let targetLocation = CLLocation(
            latitude: placeCoordinate.latitude,
            longitude: placeCoordinate.longitude
        )
        
        var totalDistance: Double = 0
        var validPlaceCount: Int = 0
        
        for placeId in listPlaceIds {
            if let detailPlace = detailPlaceViewModel.places[placeId],
               let listPlaceCoordinate = detailPlace.coordinate {
                
                let listPlaceLocation = CLLocation(
                    latitude: listPlaceCoordinate.latitude,
                    longitude: listPlaceCoordinate.longitude
                )
                
                let distance = targetLocation.distance(from: listPlaceLocation)
                totalDistance += distance
                validPlaceCount += 1
                
                print("🔍 [ProfileViewModel] List place '\(detailPlace.name)' distance: \(String(format: "%.1f km", distance/1000))")
            } else {
                print("⚠️ [ProfileViewModel] Could not find place with ID \(placeId) or it has no coordinate")
            }
        }
        
        let averageDistance = validPlaceCount > 0 ? totalDistance / Double(validPlaceCount) : Double.infinity
        print("🐌 [ProfileViewModel] SLOW: List '\(list.name)' average distance: \(averageDistance == Double.infinity ? "infinity" : String(format: "%.1f km", averageDistance/1000)) (valid places: \(validPlaceCount)/\(listPlaceIds.count))")
        
        return averageDistance
    }
    
    /// Sorts lists by their proximity to a specific place (closest first)
    func sortListsByDistanceFromPlace(_ place: DetailPlace) -> [PlaceList] {
        return userLists.sorted { list1, list2 in
            let distance1 = calculateAverageDistanceForListFromPlace(list1, place: place)
            let distance2 = calculateAverageDistanceForListFromPlace(list2, place: place)
            return distance1 < distance2
        }
    }
    
    /// Sorts lists with recently created list at the top, then by proximity to a specific place
    func sortListsWithRecentFirstFromPlace(_ place: DetailPlace) -> [PlaceList] {
        return userLists.sorted { list1, list2 in
            // If one of the lists is recently created, prioritize it
            if list1.id == recentlyCreatedListId {
                return true
            }
            if list2.id == recentlyCreatedListId {
                return false
            }
            
            // Otherwise, sort by distance
            let distance1 = calculateAverageDistanceForListFromPlace(list1, place: place)
            let distance2 = calculateAverageDistanceForListFromPlace(list2, place: place)
            return distance1 < distance2
        }
    }
    
    // MARK: - External Places (TikTok-sourced places) - OLD CODE, KEEP FOR TikTok deletion
    
    /// OLD: This function is no longer used for loading - we use lightweight loading now
    /// KEEP: Still needed for TikTok place deletion to work with userExternalPlaces dictionary
    func fetchUserExternalPlaces() {
        guard let userId = user?.id else { 
            print("❌ [ProfileViewModel] No user ID available for fetching external places")
            return 
        }
        
        print("🔍 [ProfileViewModel] Starting fetchUserExternalPlaces for user: \(userId)")
        print("🔍 [ProfileViewModel] User object: \(String(describing: user))")
        print("🔍 [ProfileViewModel] User ID type: \(type(of: userId))")
        
        userService.fetchUserExternalPlaces(userId: userId) { [weak self] result in
            guard let self = self else { 
                print("❌ [ProfileViewModel] Self is nil in fetchUserExternalPlaces callback")
                return 
            }
            
            print("📨 [ProfileViewModel] Received result from userService.fetchUserExternalPlaces")
            
            switch result {
            case .success(let externalPlaces):
                print("✅ [ProfileViewModel] Successfully fetched \(externalPlaces.count) external places")
                
                // Convert array to dictionary
                let externalPlacesDict = Dictionary(uniqueKeysWithValues: externalPlaces.map { ($0.placeId, $0) })
                
                // Update on main thread to avoid UI threading issues
                Task { @MainActor in
                    // External places details loaded
                    self.userExternalPlaces = externalPlacesDict
                    print("📚 [ProfileViewModel] Updated userExternalPlaces dictionary with \(externalPlacesDict.count) entries")
                    
                    // Load TikTok thumbnail images for external places
                    print("🖼️ [ProfileViewModel] Starting to load TikTok thumbnails...")
                    for externalPlace in externalPlaces {
                        // Get the first TikTok video's thumbnail as the place image
                        if let firstTikTokVideo = externalPlace.tiktokVideos.first,
                           !firstTikTokVideo.thumbnailUrl.isEmpty {
                            // Loading TikTok thumbnail for \(externalPlace.name)
                            self.loadTikTokThumbnailAsPlaceImage(
                                placeId: externalPlace.placeId,
                                thumbnailURL: firstTikTokVideo.thumbnailUrl
                            )
                        } else {
                            print("⚠️ [ProfileViewModel] No thumbnail available for \(externalPlace.name)")
                        }
                    }
                    print("✅ [ProfileViewModel] Completed TikTok thumbnail loading")
                }
                
            case .failure(let error):
                print("❌ [ProfileViewModel] Error fetching external places: \(error.localizedDescription)")
                print("🔍 [ProfileViewModel] Error details: \(error)")
            }
        }
    }
    
    /// Load TikTok thumbnail as place image for external places
    private func loadTikTokThumbnailAsPlaceImage(placeId: String, thumbnailURL: String) {
        // Skip if image already exists
        if detailPlaceViewModel.placeImages[placeId] != nil {
            return
        }
        
        guard let url = URL(string: thumbnailURL) else {
            print("❌ [ProfileViewModel] Invalid thumbnail URL for place \(placeId): \(thumbnailURL)")
            return
        }
        
        // Loading TikTok thumbnail for place
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileViewModel] Error loading TikTok thumbnail for \(placeId): \(error.localizedDescription)")
                } else if let data = data, let image = UIImage(data: data) {
                    // Successfully loaded TikTok thumbnail
                    // Store in DetailPlaceViewModel for popup views to access
                    self.detailPlaceViewModel.placeImages[placeId] = image
                } else {
                    print("⚠️ [ProfileViewModel] No image data returned for TikTok thumbnail \(placeId)")
                }
            }
        }.resume()
    }
    
    /// Get TikTok videos for a specific place ID
    func getTikTokVideos(for placeId: String) -> [TikTokVideo] {
        guard let externalPlace = userExternalPlaces[placeId] else {
            return []
        }
        
        // Convert ExternalTikTokVideos to TikTokVideos for compatibility
        return externalPlace.tiktokVideos.compactMap { convertExternalTikTokVideoToTikTokVideo($0) }
    }
    
    /// Check if user has TikTok videos for a specific place
    func hasTikTokVideos(for placeId: String) -> Bool {
        guard let externalPlace = userExternalPlaces[placeId] else {
            return false
        }
        return !externalPlace.tiktokVideos.isEmpty
    }
    
    /// Get the external place data for a specific place ID
    func getExternalPlace(for placeId: String) -> ExternalPlace? {
        return userExternalPlaces[placeId]
    }

    func loadPlaceImageWithFallback(for place: DetailPlace) {
        let placeId = place.id.uuidString
        
        // If image already exists, no need to do anything
        if detailPlaceViewModel.placeImages[placeId] != nil {
            return
        }
        
        // If there's no review image, try to load a TikTok thumbnail
        if let externalPlace = getExternalPlace(for: placeId),
           let firstTikTokVideo = externalPlace.tiktokVideos.first,
           !firstTikTokVideo.thumbnailUrl.isEmpty {
            
            userProfileViewModel?.loadTikTokThumbnailAsPlaceImage(placeId: placeId, thumbnailURL: firstTikTokVideo.thumbnailUrl) { [weak self] placeId, image in
                if let image = image {
                    self?.detailPlaceViewModel.placeImages[placeId] = image
                }
            }
        }
    }
    
    /// Load images for places with prioritization - first 8 immediately, rest in background
    func loadPriorityImagesForPlaces(_ places: [DetailPlace], priorityCount: Int = 8) {
        let priorityPlaces = Array(places.prefix(priorityCount))
        let remainingPlaces = Array(places.dropFirst(priorityCount))
        
        // Load priority places immediately
        for place in priorityPlaces {
            detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
        }
        
        // Load remaining places in background with lower priority
        if !remainingPlaces.isEmpty {
            Task.detached(priority: .background) { [weak self] in
                // Add small delay to not interfere with priority loading
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                for place in remainingPlaces {
                    await MainActor.run {
                        self?.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                    }
                    // Small delay between each background load to avoid overwhelming the system
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
        }
    }

    func deleteMyPlace(_ place: DetailPlace, completion: @escaping (Bool) -> Void) {
        guard let userId = user?.id else {
            completion(false)
            return
        }

        let placeId = place.id.uuidString
        
        // Optimistically remove from local array
        myPlaces.removeAll { $0 == placeId }
        
        // Remove from map annotations immediately (optimistic update)
        detailPlaceViewModel.places.removeValue(forKey: placeId)
        
        // Remove from placeSavers (so it doesn't appear on map)
        if var savers = detailPlaceViewModel.placeSavers[placeId] {
            savers.removeAll { $0 == userId }
            if savers.isEmpty {
                detailPlaceViewModel.placeSavers.removeValue(forKey: placeId)
            } else {
                detailPlaceViewModel.placeSavers[placeId] = savers
            }
        }
        
        // Recalculate map annotations
        detailPlaceViewModel.calculateAnnotationPlaces()
        
        // Send notification to refresh map annotations
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)

        // Asynchronously delete from backend
        Task {
            var myPlacesDeleteSuccess = false
            var allPlacesDeleteSuccess = false
            
            // Delete from my_places
            placeService.deletePlaceFromMyPlaces(userId: userId, placeId: placeId) { error in
                if let error = error {
                    print("❌ Error deleting place from my places: \(error)")
                } else {
                    myPlacesDeleteSuccess = true
                }
            }
            
            // Delete from all_places (only for custom places)
            placeService.deletePlaceFromAllPlaces(placeId: placeId) { error in
                if let error = error {
                    print("❌ Error deleting place from all places: \(error)")
                } else {
                    allPlacesDeleteSuccess = true
                }
            }
            
            // Wait a moment for both operations to complete
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // On success, call completion on main thread
            await MainActor.run {
                if myPlacesDeleteSuccess {
                    print("✅ [ProfileViewModel] Successfully deleted custom place: \(place.name)")
                    completion(true)
                } else {
                    // If deletion fails, revert the optimistic updates
                    print("❌ [ProfileViewModel] Failed to delete custom place, reverting changes")
                    myPlaces.append(placeId)
                    detailPlaceViewModel.places[placeId] = place
                    
                    // Re-add to placeSavers
                    if detailPlaceViewModel.placeSavers[placeId] == nil {
                        detailPlaceViewModel.placeSavers[placeId] = [userId]
                    } else if !detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                        detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                    }
                    
                    // Recalculate map annotations
                    detailPlaceViewModel.calculateAnnotationPlaces()
                    
                    // Send notification to refresh map annotations
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)
                    
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Account Deletion
    
    /// Delete user account and all associated data
    func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let userId = user?.id else {
            completion(false, "No user ID found")
            return
        }
        
        print("🗑️ [ProfileViewModel] Starting account deletion for user: \(userId)")
        
        // Delete user data from Firestore
        userService.deleteUserAccount(userId: userId) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ProfileViewModel] Error deleting account: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                } else {
                    print("✅ [ProfileViewModel] Successfully deleted user data from Supabase")
                    
                    // Delete Supabase Auth user
                    Task { @MainActor in
                        do {
                            try await SupabaseAuthService.shared.deleteAccount()
                            print("✅ [ProfileViewModel] Successfully deleted Supabase Auth user")
                            
                            // Log out the user
                            self?.userSession.logout()
                            
                            completion(true, nil)
                        } catch {
                            print("❌ [ProfileViewModel] Error deleting Supabase Auth user: \(error.localizedDescription)")
                            completion(false, "Failed to delete authentication account: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
