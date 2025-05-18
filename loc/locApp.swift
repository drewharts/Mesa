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
    @StateObject private var userSession: UserSession
    @StateObject private var profileViewModel: ProfileViewModel
    @StateObject private var detailPlaceViewModel: DetailPlaceViewModel
    @StateObject private var selectedPlaceViewModel: SelectedPlaceViewModel
    private let dataManager: DataManager

    init() {
        FirebaseApp.configure()
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        let firestore = FirestoreService()
        let location = LocationManager()
        let detailVM = DetailPlaceViewModel(firestoreService: firestore)
        let userSess = UserSession(firestoreService: firestore, locationManager: location, detailPlaceVM: detailVM)
        let profileVM = ProfileViewModel(userSession: userSess, firestoreService: firestore, detailPlaceViewModel: detailVM)
        let selectedPlaceVM = SelectedPlaceViewModel(locationManager: location, firestoreService: firestore)
        
        // Initialize DataManager with all required parameters
        let dataMgr = DataManager(
            fireStoreService: firestore,
            userSession: userSess,
            locationManager: location,
            profileViewModel: profileVM,
            detailPlaceViewModel: detailVM
        )

        self._firestoreService = StateObject(wrappedValue: firestore)
        self._locationManager = StateObject(wrappedValue: location)
        self._userSession = StateObject(wrappedValue: userSess)
        self._profileViewModel = StateObject(wrappedValue: profileVM)
        self._detailPlaceViewModel = StateObject(wrappedValue: detailVM)
        self.dataManager = dataMgr
        self._selectedPlaceViewModel = StateObject(wrappedValue: selectedPlaceVM)
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(userSession)
                .environmentObject(locationManager)
                .environmentObject(profileViewModel)
                .environmentObject(detailPlaceViewModel)
                .environmentObject(selectedPlaceViewModel)
                .environmentObject(firestoreService)
                .environmentObject(dataManager)
                .preferredColorScheme(.light)
                .onAppear {
                    if let currentUser = Auth.auth().currentUser {
                        userSession.isUserLoggedIn = true
                        userSession.currentUserId = currentUser.uid
                        // Initialize profile data using data manager
                        dataManager.initializeProfileData(userId: currentUser.uid)
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
