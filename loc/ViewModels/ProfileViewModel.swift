//  ProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import Combine
import MapboxSearch
import Foundation
import FirebaseFirestore
import UIKit

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: ProfileData? 
    @Published var userPicture: UIImage?
    @Published var userLists: [PlaceList] = []
    @Published var userListsPlaces: [String: [String]] = [:] // [listId: [placeId]]
    @Published var userFavorites: [String] = []
    @Published var userFollowing: [ProfileData] = []
    @Published var userFollowers: [ProfileData] = []
    //TODO: Implement my places
    @Published var myPlaces: [String] = []
    
     private let firestoreService: FirestoreService
     internal let detailPlaceViewModel: DetailPlaceViewModel
     private let userSession: UserSession
     @Published var showMaxFavoritesAlert: Bool = false
     @Published var isLoading: Bool = true
     private var loadingTasks: Int = 0
     @Published var followersCount: Int = 0
     @Published var followingCount: Int = 0
    
    init(userSession: UserSession, firestoreService: FirestoreService, detailPlaceViewModel: DetailPlaceViewModel) {
         self.firestoreService = firestoreService
         self.detailPlaceViewModel = detailPlaceViewModel
        self.userSession = userSession
     }
    
    func startLoading() {
        loadingTasks += 1
        isLoading = true
    }
    
    func finishLoading() {
        loadingTasks -= 1
        if loadingTasks <= 0 {
            isLoading = false
        }
    }
    
     func changeProfilePhoto(_ newImage: UIImage) async {
        guard let userId = user?.id else { return }
        startLoading()
        let croppedImage = cropToSquare(newImage)
        do {
            let url = try await firestoreService.updateProfilePhoto(userId: userId, image: croppedImage)
            // Update local user and userPicture
            DispatchQueue.main.async {
                self.user?.profilePhotoURL = url
                self.userPicture = croppedImage
                self.finishLoading()
            }
        } catch {
            print("Failed to update profile photo: \(error)")
            DispatchQueue.main.async {
                self.finishLoading()
            }
        }
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
        if userFollowing.contains(where: { $0.id == userId }) {
            // Unfollow
            firestoreService.unfollowUser(followerId: currentUserId, followingId: userId) { [weak self] success, error in
                if success {
                    self?.userFollowing.removeAll { $0.id == userId }
                    self?.followingCount = max(0, (self?.followingCount ?? 1) - 1)
                }
            }
        } else {
            // Follow
            firestoreService.followUser(followerId: currentUserId, followingId: userId) { [weak self] success, error in
                if success {
                    // Fetch the ProfileData for the followed user and add to userFollowing
                    self?.firestoreService.fetchUserById(userId: userId) { result in
                        if case .success(let profileData) = result {
                            self?.userFollowing.append(profileData)
                        }
                        self?.followingCount += 1
                    }
                }
            }
        }
    }
    
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
    
    func addFavoriteFromSuggestion(place: MesaPlaceSuggestion) {
        //get rid of this in the future
    }
    
     func isPlaceInList(listId: UUID, placeId: String) -> Bool {
         return false
     }
    
     func addPlaceToList(listId: UUID, place: DetailPlace) {
        let listIdString = listId.uuidString
        guard let userId = userSession.currentUserId else { return }
        // Find the list in userLists
        guard let listIndex = userLists.firstIndex(where: { $0.id == listId }) else { return }
        // Convert DetailPlace to Place for FirestoreService
        let placeForList = Place(id: place.id, name: place.name, address: place.address ?? "")
        // Update local userListsPlaces
        var places = userListsPlaces[listIdString] ?? []
        if !places.contains(place.id.uuidString) {
            places.append(place.id.uuidString)
            userListsPlaces[listIdString] = places
        }
        // Update the places array in the PlaceList
        if !userLists[listIndex].places.contains(where: { $0.id == place.id }) {
            userLists[listIndex].places.append(placeForList)
        }
        // Persist to Firestore
        firestoreService.addPlaceToList(userId: userId, listName: listIdString, place: placeForList)
        // Update DetailPlaceViewModel's places dictionary for immediate UI update
        if detailPlaceViewModel.places[place.id.uuidString] == nil {
            detailPlaceViewModel.places[place.id.uuidString] = place
        }
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
         
         let placeForList = Place(id: place.id, name: place.name, address: place.address ?? "")


         firestoreService.removePlaceFromList(userId: userId, listId: list.id, place: placeForList)
     }
    
     func removeFavoritePlace(place: DetailPlace) {

     }
    
     func addNewPlaceList(named name: String, city: String, emoji: String, image: String) {
         let newPlaceList = PlaceList(name: name, city: city, emoji: emoji, image: image)
         userLists.append(newPlaceList)
         guard let userId = user?.id else { return }
         firestoreService.createNewList(placeList: newPlaceList, userID: userId)
     }
    
     func removePlaceList(placeList: PlaceList) {
         if let index = userLists.firstIndex(where: { $0.id == placeList.id }) {
             userLists.remove(at: index)
             firestoreService.deleteList(userId: userSession.currentUserId!,listId: placeList.id.uuidString) { error in
                 if error == nil, let index = self.userLists.firstIndex(where: { $0.id == placeList.id }) {
                     self.userLists.remove(at: index)
                 }
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
}
