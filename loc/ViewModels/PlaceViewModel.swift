//
//  PlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/22/25.
//


// PlaceViewModel.swift
import Foundation
import Combine
import SwiftUI

class PlaceViewModel: ObservableObject, Identifiable {
    let id: String // placeID
    let place: Place
    @Published var placeImage: UIImage? = nil

    // Optional: Error handling
    @Published var hasError: Bool = false
    @Published var errorMessage: String = ""

    private var cancellables = Set<AnyCancellable>()

    init(place: Place) {
        self.place = place
        self.id = place.id.uuidString
    }


}
