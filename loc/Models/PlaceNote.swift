//
//  PlaceNote.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation
import FirebaseFirestore

struct PlaceNote: Codable, Identifiable {
    var id: String = UUID().uuidString
    var placeId: String
    var userId: String
    var note: String?
    var link: String?
    var createdAt: Timestamp
    var updatedAt: Timestamp
    
    init(placeId: String, userId: String, note: String? = nil, link: String? = nil) {
        self.placeId = placeId
        self.userId = userId
        self.note = note
        self.link = link
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
    
    // Computed property to check if note has content
    var hasContent: Bool {
        return (note != nil && !note!.isEmpty) || (link != nil && !link!.isEmpty)
    }
    
    // Computed property to get display text
    var displayText: String {
        if let note = note, !note.isEmpty {
            return note
        } else if let link = link, !link.isEmpty {
            return "Link: \(link)"
        }
        return ""
    }
}
