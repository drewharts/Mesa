//
//  AccountType.swift
//  loc
//
//  Defines the account type for user profiles (personal vs curated/brand).
//

import Foundation

/// Distinguishes personal user accounts from curated brand profiles.
enum AccountType: String, Codable {
    case personal = "personal"
    case curated = "curated"
}
