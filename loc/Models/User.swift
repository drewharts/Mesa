//
//  User.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/18/24.
//


import Foundation

struct User: Codable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let profilePhotoURL: URL?
    let fullName: String
    let accountType: AccountType?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case profilePhotoURL = "profile_photo_url"
        case fullName = "full_name"
        case accountType = "account_type"
    }
}
