//
//  DetailPlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/22/25.
//

import Foundation

class DetailPlaceViewModel: ObservableObject {
    @Published var places: [String: DetailPlace] = [:]
    @Published var placeReviews: [String: [Review]] = [:]
    
    private let firestoreService: FirestoreService

    init(firestore: FirestoreService) {
        self.firestoreService = firestore
    }
    
}
