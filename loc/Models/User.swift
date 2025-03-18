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
}
