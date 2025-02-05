//
//  MapPlaceUserInfo.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/4/25.
//

import Foundation


struct MapPlaceUserInfo: Codable {
    let userId: String
    let type: String       // e.g., "favorite" or "list"
    let listId: String?    // if applicable, for when the place is added to a specific list
    let addedAt: Date
}
