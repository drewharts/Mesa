//
//  locApp.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import GoogleMaps
import GooglePlaces

@main
struct locApp: App {
    init() {
        GMSServices.provideAPIKey("AIzaSyDKwWpvVoYjZg-cXmZSgXOSieRnjiQzY74")
        GMSPlacesClient.provideAPIKey("AIzaSyDKwWpvVoYjZg-cXmZSgXOSieRnjiQzY74")
    }
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
    }
}
