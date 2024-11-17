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
    @StateObject private var userSession = UserSession() // Initialize UserSession

    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Use App Attest Provider on a physical device
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Initialize Google Maps and Google Places API keys
        GMSServices.provideAPIKey("AIzaSyAfhLbm8NlOqjqQRR9aAtNdSEYIfZocrVE")
        GMSPlacesClient.provideAPIKey("AIzaSyAfhLbm8NlOqjqQRR9aAtNdSEYIfZocrVE")
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

// AppDelegate: Updated to handle Google Sign-In callbacks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        FirebaseApp.configure()
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// App Check Provider Factory using App Attest only for physical devices
class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}
