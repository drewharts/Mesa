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
    
    // Declare @StateObject properties without initializers
    @StateObject private var firestoreService: FirestoreService
    @StateObject private var locationManager: LocationManager
    @StateObject private var detailPlaceVM: DetailPlaceViewModel
    @StateObject private var selectedPlaceVM: SelectedPlaceViewModel
    @StateObject private var userSession: UserSession

    init() {
        // Configure Firebase and App Check
        FirebaseApp.configure()
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Initialize Google Maps and Places API keys
        GMSServices.provideAPIKey("AIzaSyD0E96aor4slzQTgo24aflktGJzbjgQkB4")
        GMSPlacesClient.provideAPIKey("AIzaSyD0E96aor4slzQTgo24aflktGJzbjgQkB4")

        // Create shared instances with proper dependencies
        let firestore = FirestoreService()
        let location = LocationManager()
        let detailVM = DetailPlaceViewModel(firestoreService: firestore)
        let selectedVM = SelectedPlaceViewModel(locationManager: location, firestoreService: firestore)
        let userSess = UserSession(firestoreService: firestore, locationManager: location, detailPlaceVM: detailVM)

        // Assign to @StateObject properties
        self._firestoreService = StateObject(wrappedValue: firestore)
        self._locationManager = StateObject(wrappedValue: location)
        self._detailPlaceVM = StateObject(wrappedValue: detailVM)
        self._selectedPlaceVM = StateObject(wrappedValue: selectedVM)
        self._userSession = StateObject(wrappedValue: userSess)
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(userSession)
                .environmentObject(locationManager)
                .environmentObject(selectedPlaceVM)
                .environmentObject(detailPlaceVM)
                .environmentObject(firestoreService)
                .onAppear {
                    if let currentUser = Auth.auth().currentUser {
                        userSession.isUserLoggedIn = true
                        userSession.fetchProfile(for: currentUser.uid)
                    }
                }
        }
    }
}

// AppDelegate and AppAttestProviderFactory remain unchanged
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
        return AppAttestProvider(app: app)
    }
}
