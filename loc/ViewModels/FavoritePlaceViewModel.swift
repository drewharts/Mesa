//
//  FavoritePlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//


// FavoritePlaceViewModel.swift
import Foundation
import Combine
import SwiftUI

class FavoritePlaceViewModel: ObservableObject, Identifiable {
    let id: String // placeID
    let place: Place
    @Published var placeImage: UIImage? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init(place: Place) {
        self.place = place
        self.id = place.id.uuidString
//        fetchGMSPlace()
    }
}
