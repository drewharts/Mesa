//
//  PlaceFlag.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation

enum PlaceFlagType: String, CaseIterable, Codable {
    case unableToIdentify = "unable_to_identify"
    case wrongSuggestion = "wrong_suggestion"
    
    var displayName: String {
        switch self {
        case .unableToIdentify:
            return "Unable to identify place"
        case .wrongSuggestion:
            return "Wrong suggestion"
        }
    }
    
    var description: String {
        switch self {
        case .unableToIdentify:
            return "The system couldn't identify a specific place from this video"
        case .wrongSuggestion:
            return "The suggested place is incorrect for this video"
        }
    }
}

struct PlaceFlag: Codable, Identifiable {
    var id: String = UUID().uuidString
    var placeId: String
    var userId: String
    var flagType: PlaceFlagType
    var contentUrl: String?
    var userComment: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    init(placeId: String, userId: String, flagType: PlaceFlagType, contentUrl: String? = nil, userComment: String? = nil) {
        self.placeId = placeId
        self.userId = userId
        self.flagType = flagType
        self.contentUrl = contentUrl
        self.userComment = userComment
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
