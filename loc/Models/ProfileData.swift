//
//  Profile.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import SwiftUI

struct ProfileData: Codable, Identifiable, Hashable {
    let id: String
    var firstName: String
    var lastName: String
    var email: String
    var profilePhotoURL: URL?
    var phoneNumber: String?
    var fullNameLower: String?
    var fullName: String
    var fcmToken: String?
    var firebaseUid: String?
    var supabaseUid: String?

    // Map camelCase properties to snake_case database columns
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case profilePhotoURL = "profile_photo_url"
        case phoneNumber = "phone_number"
        case fullNameLower = "full_name_lower"
        case fullName = "full_name"
        case fcmToken = "fcm_token"
        case firebaseUid = "firebase_uid"
        case supabaseUid = "supabase_uid"
    }
}
