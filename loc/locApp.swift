//
//  locApp.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import GoogleMaps
import GooglePlaces
import Firebase
import FirebaseAuth

@main
struct locApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userSession = UserSession() // Initialize UserSession

    init() {
        // Initialize Google Maps and Google Places API keys
        GMSServices.provideAPIKey("AIzaSyDKwWpvVoYjZg-cXmZSgXOSieRnjiQzY74")
        GMSPlacesClient.provideAPIKey("AIzaSyDKwWpvVoYjZg-cXmZSgXOSieRnjiQzY74")
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(userSession) // Inject UserSession into the environment
                .onAppear {
                    // Set `isUserLoggedIn` to true if a user is already authenticated
                    if Auth.auth().currentUser != nil {
                        userSession.isUserLoggedIn = true
                    }
                }
        }
    }
}

// FirebaseApp configuration in AppDelegate if needed
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

