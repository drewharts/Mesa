//
//  PhoneNumberNormalizer.swift
//  loc
//
//  Pure utility for normalizing phone numbers to E.164 format.
//

import Foundation

enum PhoneNumberNormalizer {

    /// Normalizes a raw phone input into E.164 format (e.g. "+14155551234").
    static func normalize(_ input: String, dialCode: String) -> String? {
        let digitsOnly = input.filter(\.isWholeNumber)
        guard digitsOnly.count >= 7 else { return nil }

        let cleanDialCode = dialCode.filter(\.isWholeNumber)

        // If user already typed the dial code, avoid doubling it
        if digitsOnly.hasPrefix(cleanDialCode) {
            return "+\(digitsOnly)"
        }

        return "+\(cleanDialCode)\(digitsOnly)"
    }

    /// Formats an E.164 number for display (e.g. "+1 (415) 555-1234" for US numbers).
    static func formatForDisplay(_ e164: String) -> String {
        let digitsOnly = e164.filter(\.isWholeNumber)

        // US/CA numbers: format as (XXX) XXX-XXXX
        if digitsOnly.count == 11, digitsOnly.hasPrefix("1") {
            let areaStart = digitsOnly.index(digitsOnly.startIndex, offsetBy: 1)
            let areaEnd = digitsOnly.index(areaStart, offsetBy: 3)
            let midEnd = digitsOnly.index(areaEnd, offsetBy: 3)
            let area = digitsOnly[areaStart..<areaEnd]
            let mid = digitsOnly[areaEnd..<midEnd]
            let last = digitsOnly[midEnd...]
            return "+1 (\(area)) \(mid)-\(last)"
        }

        // Generic international: just add "+"
        return "+\(digitsOnly)"
    }
}
