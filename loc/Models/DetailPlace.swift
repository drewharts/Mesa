//
//  DetailPlace.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/10/25.
//

import Foundation
import FirebaseFirestore
import MapboxSearch

struct DetailPlace: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var address: String?
    var city: String?
    var mapboxId: String?
    var coordinate: GeoPoint?
    var categories: [String]?
    var phone: String?
    var rating: Double?
    var openHours: [String]?
    var description: String?
    var priceLevel: String?
    var reservable: Bool?
    var servesBreakfast: Bool?
    var serversLunch: Bool?
    var serversDinner: Bool?
    var Instagram: String?
    var X: String?

    // Existing initializers unchanged
    init() {
        self.id = UUID()
        self.name = ""
        self.address = nil
        self.mapboxId = nil
        self.coordinate = nil
        self.categories = nil
        self.phone = nil
        self.rating = nil
        self.openHours = nil
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
        self.openHours = nil
        self.description = nil
        self.priceLevel = nil
        self.reservable = nil
        self.servesBreakfast = nil
        self.serversLunch = nil
        self.serversDinner = nil
        self.Instagram = nil
        self.X = nil
    }
    
    init(id: UUID, name: String, address: String?, city: String?) {
        self.id = id
        self.name = name
        self.address = address
        self.city = city
        self.mapboxId = nil
        self.coordinate = nil
        self.categories = nil
        self.phone = nil
        self.rating = nil
        self.openHours = nil
        self.description = nil
        self.priceLevel = nil
        self.reservable = nil
        self.servesBreakfast = nil
        self.serversLunch = nil
        self.serversDinner = nil
        self.Instagram = nil
        self.X = nil
    }

    init(from searchResult: SearchResult) {
        self.id = UUID()
        self.name = searchResult.name
        self.address = searchResult.address?.formattedAddress(style: .medium)
        self.city = searchResult.address?.place
        self.mapboxId = searchResult.id
        self.coordinate = GeoPoint(
            latitude: searchResult.coordinate.latitude,
            longitude: searchResult.coordinate.longitude
        )
        self.categories = searchResult.categories
        self.phone = searchResult.metadata?.phone
        self.rating = searchResult.metadata?.rating
        
        // Handle OpenHours
        if let openHours = searchResult.metadata?.openHours as? OpenHours {
            self.openHours = DetailPlace.serializeOpenHours(openHours)
        } else {
            self.openHours = nil
        }
        
        self.description = searchResult.metadata?.description
        self.priceLevel = searchResult.metadata?.priceLevel
        self.reservable = searchResult.metadata?.reservable
        self.servesBreakfast = searchResult.metadata?.servesBreakfast
        self.serversLunch = searchResult.metadata?.servesLunch
        self.serversDinner = searchResult.metadata?.servesDinner
        self.Instagram = searchResult.metadata?.instagram
        self.X = searchResult.metadata?.twitter
    }

    public static func serializeOpenHours(_ openHours: OpenHours) -> [String] {
        switch openHours {
        case .alwaysOpened:
            return ["always_opened"]
        case .temporarilyClosed:
            return ["temporarily_closed"]
        case .permanentlyClosed:
            return ["permanently_closed"]
        case .scheduled(periods: let periods, weekdayText: let weekdayText, note: let note):
            var result: [String] = periods.map { period in
                // Extract from start and end (DateComponents)
                let open = "\(period.start.weekday ?? 0):\(period.start.hour ?? 0):\(period.start.minute ?? 0)"
                let close = "\(period.end.weekday ?? 0):\(period.end.hour ?? 0):\(period.end.minute ?? 0)"
                return "\(open)-\(close)"
            }
            if let weekdayText = weekdayText {
                result.append(contentsOf: weekdayText)
            }
            if let note = note {
                result.append("note:\(note)")
            }
            return result
        }
    }
}
