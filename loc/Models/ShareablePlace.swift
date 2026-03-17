//
//  ShareablePlace.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import Foundation

struct ShareablePlace: Codable, Identifiable {
    let id: String
    let name: String
    let address: String?
    let city: String?
    let mapboxId: String?
    let latitude: Double?
    let longitude: Double?
    
    init(from detailPlace: DetailPlace) {
        self.id = detailPlace.id.uuidString
        self.name = detailPlace.name
        self.address = detailPlace.address
        self.city = detailPlace.city
        self.mapboxId = detailPlace.mapboxId
        self.latitude = detailPlace.coordinate?.latitude
        self.longitude = detailPlace.coordinate?.longitude
    }
    
    init(from nearbyPlace: NearbyPlaceFeature) {
        self.id = nearbyPlace.id
        self.name = nearbyPlace.properties.name
        self.address = nearbyPlace.properties.address
        self.city = nil
        self.mapboxId = nearbyPlace.properties.placeId
        self.latitude = nearbyPlace.geometry.latitude
        self.longitude = nearbyPlace.geometry.longitude
    }
    
    init(id: String, name: String, address: String?, city: String?, mapboxId: String?, latitude: Double?, longitude: Double?) {
        self.id = id
        self.name = name
        self.address = address
        self.city = city
        self.mapboxId = mapboxId
        self.latitude = latitude
        self.longitude = longitude
    }
    
    var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "loc"
        components.host = "place"
        components.path = "/\(id)"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: name))
        
        if let address = address {
            queryItems.append(URLQueryItem(name: "address", value: address))
        }
        
        if let city = city {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }
        
        if let mapboxId = mapboxId {
            queryItems.append(URLQueryItem(name: "mapboxId", value: mapboxId))
        }
        
        if let latitude = latitude {
            queryItems.append(URLQueryItem(name: "lat", value: String(latitude)))
        }
        
        if let longitude = longitude {
            queryItems.append(URLQueryItem(name: "lng", value: String(longitude)))
        }
        
        components.queryItems = queryItems
        return components.url
    }
    
    static func from(url: URL) -> ShareablePlace? {
        guard url.scheme == "loc",
              url.host == "place",
              !url.pathComponents.isEmpty else {
            return nil
        }

        let pathComponents = url.pathComponents
        guard pathComponents.count > 1 else {
            return nil
        }

        let placeId = String(pathComponents[1])

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        var name: String?
        var address: String?
        var city: String?
        var mapboxId: String?
        var latitude: Double?
        var longitude: Double?
        
        for item in queryItems {
            switch item.name {
            case "name":
                name = item.value
            case "address":
                address = item.value
            case "city":
                city = item.value
            case "mapboxId":
                mapboxId = item.value
            case "lat":
                if let value = item.value {
                    latitude = Double(value)
                }
            case "lng":
                if let value = item.value {
                    longitude = Double(value)
                }
            default:
                break
            }
        }
        
        guard let placeName = name else {
            return nil
        }

        return ShareablePlace(
            id: placeId,
            name: placeName,
            address: address,
            city: city,
            mapboxId: mapboxId,
            latitude: latitude,
            longitude: longitude
        )
    }
} 