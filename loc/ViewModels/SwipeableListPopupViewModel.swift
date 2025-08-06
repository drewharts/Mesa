//
//  SwipeableListPopupViewModel.swift
//  loc
//
//  Created by Claude Code on 1/9/25.
//

import Foundation
import SwiftUI

@MainActor
class SwipeableListPopupViewModel: ObservableObject {
    @Published var currentListIndex: Int
    @Published var showingDeleteConfirmation = false
    
    let lists: [PlaceList]
    
    init(lists: [PlaceList], initialListIndex: Int) {
        self.lists = lists
        self.currentListIndex = initialListIndex
    }
    
    var currentList: PlaceList {
        guard currentListIndex >= 0 && currentListIndex < lists.count else {
            return lists.first ?? PlaceList(
                name: "Empty",
                places: [],
                city: "",
                emoji: "📍"
            )
        }
        return lists[currentListIndex]
    }
    
    func onListIndexChanged() {
        // Trigger any needed updates when list changes
        objectWillChange.send()
    }
    
    func generateColorsForCurrentList(placeColors: inout [UUID: Color], profileViewModel: ProfileViewModel, detailPlaceViewModel: DetailPlaceViewModel) {
        guard let placeIds = profileViewModel.userListsPlaces[currentList.id.uuidString] else { return }
        let places = placeIds.compactMap { detailPlaceViewModel.places[$0] }
        
        for place in places {
            if placeColors[place.id] == nil {
                placeColors[place.id] = Color(
                    red: Double.random(in: 0...1),
                    green: Double.random(in: 0...1),
                    blue: Double.random(in: 0...1)
                )
            }
        }
    }
    
    func showDeleteConfirmation() {
        showingDeleteConfirmation = true
    }
    
    func deleteCurrentList(profileViewModel: ProfileViewModel) -> Bool {
        let listToDelete = currentList
        profileViewModel.removePlaceList(placeList: listToDelete)
        
        // Handle navigation after deletion
        if lists.count <= 1 {
            // If this was the last list, should close the popup
            return true
        } else if currentListIndex >= lists.count - 1 {
            // If we deleted the last list, move to the previous one
            currentListIndex = max(0, currentListIndex - 1)
        }
        // If we deleted a middle list, currentListIndex stays the same,
        // which will show the next list in the array
        
        return false // Don't close popup
    }
}
