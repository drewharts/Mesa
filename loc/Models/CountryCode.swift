//
//  CountryCode.swift
//  loc
//
//  Model representing a country with its phone dial code and flag emoji.
//

import Foundation

struct CountryCode: Identifiable, Hashable {
    let id: String        // ISO 3166-1 alpha-2 code (e.g. "US")
    let name: String
    let dialCode: String  // e.g. "+1"
    let flag: String      // Emoji flag (e.g. "🇺🇸")

    /// Common countries for the phone number picker, US first.
    static let common: [CountryCode] = [
        CountryCode(id: "US", name: "United States", dialCode: "+1", flag: "🇺🇸"),
        CountryCode(id: "CA", name: "Canada", dialCode: "+1", flag: "🇨🇦"),
        CountryCode(id: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧"),
        CountryCode(id: "AU", name: "Australia", dialCode: "+61", flag: "🇦🇺"),
        CountryCode(id: "DE", name: "Germany", dialCode: "+49", flag: "🇩🇪"),
        CountryCode(id: "FR", name: "France", dialCode: "+33", flag: "🇫🇷"),
        CountryCode(id: "IT", name: "Italy", dialCode: "+39", flag: "🇮🇹"),
        CountryCode(id: "ES", name: "Spain", dialCode: "+34", flag: "🇪🇸"),
        CountryCode(id: "MX", name: "Mexico", dialCode: "+52", flag: "🇲🇽"),
        CountryCode(id: "BR", name: "Brazil", dialCode: "+55", flag: "🇧🇷"),
        CountryCode(id: "IN", name: "India", dialCode: "+91", flag: "🇮🇳"),
        CountryCode(id: "JP", name: "Japan", dialCode: "+81", flag: "🇯🇵"),
        CountryCode(id: "KR", name: "South Korea", dialCode: "+82", flag: "🇰🇷"),
        CountryCode(id: "CN", name: "China", dialCode: "+86", flag: "🇨🇳"),
        CountryCode(id: "NL", name: "Netherlands", dialCode: "+31", flag: "🇳🇱"),
        CountryCode(id: "SE", name: "Sweden", dialCode: "+46", flag: "🇸🇪"),
        CountryCode(id: "CH", name: "Switzerland", dialCode: "+41", flag: "🇨🇭"),
        CountryCode(id: "NZ", name: "New Zealand", dialCode: "+64", flag: "🇳🇿"),
        CountryCode(id: "IE", name: "Ireland", dialCode: "+353", flag: "🇮🇪"),
        CountryCode(id: "PT", name: "Portugal", dialCode: "+351", flag: "🇵🇹")
    ]

    /// Returns the default country code (US).
    static var defaultCountry: CountryCode {
        common[0]
    }
}
