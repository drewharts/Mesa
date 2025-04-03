import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseAppCheck
import GoogleSignIn

@main
struct locApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var firestoreService: FirestoreService
    @StateObject private var locationManager: LocationManager
    @StateObject private var detailPlaceVM: DetailPlaceViewModel
    @StateObject private var selectedPlaceVM: SelectedPlaceViewModel
    @StateObject private var userSession: UserSession

    init() {
        FirebaseApp.configure()
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Run migrations right after Firebase configuration
//        MigrationManager.shared.runMigrations { error in
//            if let error = error {
//                print("Migration failed: \(error.localizedDescription)")
//            } else {
//                print("Migrations completed successfully")
//            }
//        }
        let firestore = FirestoreService()
        let profileFirestore = ProfileFirestoreService()
        let location = LocationManager()
        let detailVM = DetailPlaceViewModel(firestoreService: firestore)
        let selectedVM = SelectedPlaceViewModel(locationManager: location, firestoreService: firestore)
        let userSess = UserSession(firestoreService: firestore, locationManager: location, detailPlaceVM: detailVM)

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
