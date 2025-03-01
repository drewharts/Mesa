//
//  DetailPlace.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/10/25.
//

import Foundation
import FirebaseFirestore

struct DetailPlace: Codable, Identifiable,Equatable {
    
    init() {
        self.id = UUID()
        self.name = ""
        self.address = nil
        
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
    
    init(id: UUID, name: String, address: String?) {
        self.id = id
        self.name = name
        self.address = address
        
        // Set all other optional properties to nil
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
    var name: String
    var address: String?
    var mapboxId: String?
    var coordinate: GeoPoint?
    var categories: [String]?
    var phone: String?
    var rating: Double?
    var OpenHours: [String]?
    var description: String?
    var priceLevel: String?
    var reservable: Bool?
    var servesBreakfast: Bool?
    var serversLunch: Bool?
    var serversDinner: Bool?
    var Instagram: String?
    var X: String?
}
