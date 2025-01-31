//
//  Follow.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/30/25.
//

import Foundation
import FirebaseFirestore

struct Follow: Codable, Identifiable {
    @DocumentID var id: String?  // Firestore document ID (optional)
    let followerId: String  // User who follows
    let followingId: String  // User being followed
    let followedAt: Date  // Timestamp when the follow happened

    // Computed property for unique ID (Firestore document ID)
    var followId: String {
        return "\(followerId)_\(followingId)"
    }
}
