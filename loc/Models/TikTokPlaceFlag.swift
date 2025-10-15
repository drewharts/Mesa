//
//  TikTokPlaceFlag.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation

enum TikTokPlaceFlagType: String, CaseIterable, Codable {
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
            return "The system couldn't identify a specific place from this TikTok video"
        case .wrongSuggestion:
            return "The suggested place is incorrect for this TikTok video"
        }
    }
}

struct TikTokPlaceFlag: Codable, Identifiable {
    var id: String = UUID().uuidString
    var placeId: String
    var userId: String
    var flagType: TikTokPlaceFlagType
    var tikTokUrl: String?
    var userComment: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    init(placeId: String, userId: String, flagType: TikTokPlaceFlagType, tikTokUrl: String? = nil, userComment: String? = nil) {
        self.placeId = placeId
        self.userId = userId
        self.flagType = flagType
        self.tikTokUrl = tikTokUrl
        self.userComment = userComment
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
