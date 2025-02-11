//
//  DetailPlace.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/10/25.
//

import Foundation
import FirebaseFirestore

struct DetailPlace: Codable, Identifiable {
    
    init(place: Place) {
        self.id = place.id
        self.name = place.name
        self.address = place.address
        
        self.mapboxId = nil
        self.coordinate = nil
        self.categories = nil
        self.phone = nil
        self.rating = nil
        self.OpenHours = nil
        self.description = nil
        self.priceLevel = nil
        self.reservable = nil
        self.servesBreakfast = nil
        self.serversLunch = nil
        self.serversDinner = nil
        self.Instagram = nil
        self.X = nil
        
    }
    var id: UUID = UUID()
    let name: String
    let address: String?
    let mapboxId: String?
    let coordinate: GeoPoint?
    let categories: [String]?
    let phone: String?
    let rating: Double?
    let OpenHours: [String]?
    let description: String?
    let priceLevel: String?
    let reservable: Bool?
    let servesBreakfast: Bool?
    let serversLunch: Bool?
    let serversDinner: Bool?
    let Instagram: String?
    let X: String?
}
