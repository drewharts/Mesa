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
import FirebaseAppCheck
import GoogleSignIn

@main
struct locApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userSession = UserSession(firestoreService: FirestoreService())

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // App Check Provider Factory
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Initialize Google Maps and Google Places API keys
        GMSServices.provideAPIKey("AIzaSyD0E96aor4slzQTgo24aflktGJzbjgQkB4")
        GMSPlacesClient.provideAPIKey("AIzaSyD0E96aor4slzQTgo24aflktGJzbjgQkB4")
        
        #if targetEnvironment(simulator)
            print("Running on Simulator - Using DebugAppCheckProvider")
        #else
            print("Running on Device - Using AppAttestProvider")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(userSession)
                .onAppear {
                    if let user = Auth.auth().currentUser {
                        print("User already authenticated: \(user.uid)")
                        userSession.isUserLoggedIn = true
                    } else {
                        print("No user authenticated")
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
#if targetEnvironment(simulator)
        // Use a debug provider for the simulator.
        if let provider = DebugAppCheckProvider(app: app) {
            print("DebugAppCheckProvider created")
            return provider
        }
        print("Error: Could not create DebugAppCheckProvider")
        return nil
#else
        // Use App Attest on physical devices.
        if let provider = AppAttestProvider(app: app) {
            print("AppAttestProvider created")
            return provider
        }
        print("Error: Could not create AppAttestProvider")
        return nil
#endif
    }
}
