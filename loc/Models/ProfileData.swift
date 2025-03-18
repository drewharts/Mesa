//
//  Profile.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import SwiftUI
import GooglePlaces

struct ProfileData: Codable, Identifiable {
    let id: String
    var firstName: String
    var lastName: String
    var email: String
    var profilePhotoURL: URL?
    var phoneNumber: String
    
    var fullName: String
}
