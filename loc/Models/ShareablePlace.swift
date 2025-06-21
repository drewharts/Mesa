//
//  ShareablePlace.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import Foundation
import FirebaseFirestore

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
        print("🔍 Parsing URL: \(url)")
        print("🔍 URL scheme: \(url.scheme ?? "nil")")
        print("🔍 URL host: \(url.host ?? "nil")")
        print("🔍 URL path: \(url.path)")
        print("🔍 URL pathComponents: \(url.pathComponents)")
        
        guard url.scheme == "loc",
              url.host == "place",
              !url.pathComponents.isEmpty else {
            print("❌ URL validation failed: scheme=\(url.scheme ?? "nil"), host=\(url.host ?? "nil"), pathComponents.count=\(url.pathComponents.count)")
            return nil
        }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count > 1 else { 
            print("❌ Not enough path components: \(pathComponents)")
            return nil 
        }
        
        let placeId = String(pathComponents[1])
        print("🔍 Extracted placeId: \(placeId)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("❌ Failed to get URL components or query items")
            return nil
        }
        
        print("🔍 Query items: \(queryItems)")
        
        var name: String?
        var address: String?
        var city: String?
        var mapboxId: String?
        var latitude: Double?
        var longitude: Double?
        
        for item in queryItems {
            print("🔍 Processing query item: \(item.name) = \(item.value ?? "nil")")
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
                print("🔍 Unknown query parameter: \(item.name)")
                break
            }
        }
        
        guard let placeName = name else { 
            print("❌ No place name found in URL")
            return nil 
        }
        
        print("✅ Successfully parsed ShareablePlace: name=\(placeName), id=\(placeId)")
        
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