//
//  Follow.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/30/25.
//

import Foundation

struct Follow: Codable, Identifiable {
    var id: String?  // Document ID
    let followerId: String  // User who follows
    let followingId: String  // User being followed
    let followedAt: Date  // Timestamp when the follow happened

    // Computed property for unique ID (Firestore document ID)
    var followId: String {
        return "\(followerId)_\(followingId)"
    }
}
