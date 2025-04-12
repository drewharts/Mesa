//
//  ReviewProtocol.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/11/25.
//

import Foundation

enum ReviewType: String, Codable {
    case generic = "generic"
    case restaurant = "restaurant"
}

protocol ReviewProtocol: Codable {
    var id: String { get }
    var userId: String { get }
    var profilePhotoUrl: String { get }
    var userFirstName: String { get }
    var userLastName: String { get }
    var placeId: String { get }
    var placeName: String { get }
    var reviewText: String { get }
    var timestamp: Date { get }
    var images: [String] { get set }
    var likes: Int { get set }
    var type: ReviewType { get }
}
