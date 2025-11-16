//
//  PlaceListSelectionViewModel.swift
//  loc
//
//  Created by Cursor on 3/1/25.
//  ViewModel responsible for "Save to List" flow
//

import Foundation
import CoreLocation

@MainActor
class PlaceListSelectionViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isLoadingInitial: Bool = false
    
    // MARK: - Dependencies
    private let profile: ProfileViewModel
    private let dataManager: DataManager
    private let userSession: UserSession
    
    // MARK: - Internal State
    private var placeCoordinates: CLLocationCoordinate2D?
    
    // MARK: - Derived State (from ProfileViewModel)
    var lists: [LightweightPlaceList] {
        profile.lightweightPlaceLists
    }
    
    var isLoadingMorePlaceLists: Bool {
        profile.isLoadingMorePlaceLists
    }
    
    var hasMorePlaceLists: Bool {
        profile.hasMorePlaceLists
    }
    
    // MARK: - Init
    init(profile: ProfileViewModel,
         dataManager: DataManager,
         userSession: UserSession) {
        self.profile = profile
        self.dataManager = dataManager
        self.userSession = userSession
    }
    
    // MARK: - Public API
    
    func loadInitialLists(for place: DetailPlace) async {
        guard let userId = userSession.currentUserId,
              let coord = place.coordinate else { return }
        
        placeCoordinates = coord
        isLoadingInitial = true
        
        await dataManager.loadPlaceListsByPlaceCoordinates(
            userId: userId,
            placeLatitude: coord.latitude,
            placeLongitude: coord.longitude
        )
        
        isLoadingInitial = false
    }
    
    func loadMoreListsIfNeeded(currentIndex: Int) async {
        guard !profile.isLoadingMorePlaceLists,
              profile.hasMorePlaceLists,
              let coord = placeCoordinates,
              let userId = userSession.currentUserId else { return }
        
        // Only trigger when we get near the end (handled by caller via index)
        await dataManager.loadMorePlaceLists(
            userId: userId,
            userLatitude: coord.latitude,
            userLongitude: coord.longitude
        )
    }
    
    func isPlace(_ place: DetailPlace, in list: LightweightPlaceList) -> Bool {
        profile.lightweightPlaceListPlaces[list.list_id]?
            .contains(where: { $0.place_id == place.id.uuidString }) ?? false
    }
    
    func toggle(place: DetailPlace, in list: LightweightPlaceList) {
        if isPlace(place, in: list) {
            profile.removePlaceFromLightweightList(listId: list.list_id, place: place)
        } else {
            profile.addPlaceToLightweightList(listId: list.list_id, place: place)
        }
    }
}


