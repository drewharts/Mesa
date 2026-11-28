//
//  DamnlinesPlaceMap.swift
//  loc
//
//  Static map of Mesa place ids to damnlines.com venue slugs (page URL last path component).
//

import Foundation

enum DamnlinesPlaceMap {
    /// Mesa place id (uppercase) -> damnlines slug. Confirmed against the Supabase places table.
    private static let slugsByPlaceId: [String: String] = [
        "B9A81082-EA4E-43AB-B7BE-5FCF178C31FD": "lindustrie-pizzeria",     // L'industrie Pizzeria, West Village
        "B89AA028-535D-44E8-ADEF-1BAFB36F4715": "banh-anh-em",             // Banh Anh Em, East Village
        "87BF7B40-9FC2-4BAA-A714-F0E61B6BF278": "the-halal-guys",          // The Halal Guys, 6th Ave & W 53rd St
        "2E8C9271-38EE-4DCD-90F9-4DA888CBC234": "golden-diner",            // Golden Diner, 123 Madison St
        "0255615F-4AF1-4EC0-A771-8804831F49DC": "johns-of-bleecker-street" // John's of Bleecker Street
    ]

    // Tracked by damnlines but NOT mapped (add if they appear in Mesa):
    // - Caffe Panna, Gramercy (77 Irving Pl): not in Mesa. Brooklyn Caffe Panna
    //   (FA19FDDC-C44C-4105-812E-1663D9ADBE70, 16 Norman Ave) is a different venue; do not map.
    // - Salt Hank's (280 Bleecker St): no Mesa place.
    // - Breakfast by Salt's Cure (27 1/2 Morton St): no Mesa place.
    // - Lucinda's (Avenue A, East Village): no Mesa place.
    // Mesa places that look similar but must NOT be mapped:
    // - L'industrie Williamsburg (F2DCD3BE-B33D-463E-9B3D-80787AA50C28): damnlines tracks West Village only.
    // - The Halal Guys, 307 E 14th St (FE04D4B7-C666-4D8A-8FB2-03A1A4635AA9): damnlines tracks Midtown only.

    /// Returns the damnlines slug for a Mesa place id (case-insensitive), or nil when unmapped.
    static func slug(forPlaceId placeId: String) -> String? {
        slugsByPlaceId[placeId.uppercased()]
    }
}
