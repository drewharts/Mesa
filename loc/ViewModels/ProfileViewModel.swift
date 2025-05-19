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
    
     // Rebuild all map annotation images completely
     func rebuildAllMapAnnotations() {
     }
    
     func toggleFollowUser(userId: String) {

     }

    
//    public func getFirstThreeProfileImages(forKey key: String) -> (UIImage?, UIImage?, UIImage?) {
////        guard let users = detailPlaceViewModel.placeSavers[key], !users.isEmpty else {
////            print("CREATING DEFAULT PROFILE IMAGES BC NO USERS FOUND")
////            let defaultImage = UIImage(named: "defaultProfile")
////            return (defaultImage, nil, nil)
////        }
////        
////        let firstThreeUsers = users.prefix(3)
////        let images = firstThreeUsers.map { user -> UIImage? in
////            if let photo = self.userProfilePhotos[user.id] {
////                return photo
////            } else {
////                // Return default image since we should have loaded all photos by now
////                return UIImage(named: "defaultProfile")
////            }
////        }
////        
////        let paddedImages = (images + [nil, nil, nil]).prefix(3)
////        return (paddedImages[0], paddedImages[1], paddedImages[2])
//    }
    
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

         firestoreService.removePlaceFromList(userId: userId, listName: list.name, placeId: place.id.uuidString)
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
