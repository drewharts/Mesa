import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseAppCheck
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

@main
struct locApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var locationManager: LocationManager
    @StateObject private var userSession: UserSession
    @StateObject private var profileViewModel: ProfileViewModel
    @StateObject private var detailPlaceViewModel: DetailPlaceViewModel
    @StateObject private var selectedPlaceViewModel: SelectedPlaceViewModel
    @StateObject private var userProfileViewModel: UserProfileViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var deepLinkManager: DeepLinkManager
    @StateObject private var deepLinkViewModel: DeepLinkViewModel
    @StateObject private var placeTypeFilterViewModel: PlaceTypeFilterViewModel
    @StateObject private var mapViewModel: MapViewModel
    
    private let dataManager: DataManager
    private let serviceContainer = ServiceContainer.shared
    
    init() {
        FirebaseApp.configure()
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Get services from container
        let services = ServiceContainer.shared
        services.setupServices()
        
        let location = services.locationManager
        
        // Pass individual services to view models (keeps current pattern)
        let detailVM = DetailPlaceViewModel(
            placeService: services.placeService, 
            userService: services.userService
        )
        
        let userSess = UserSession(
            userService: services.userService, 
            locationManager: location, 
            detailPlaceVM: detailVM
        )
        
        let selectedPlaceVM = SelectedPlaceViewModel(
            locationManager: location,
            reviewService: services.reviewService,
            placeService: services.placeService,
            userService: services.userService,
            imageService: services.imageService
        )
        
        let deepLinkMgr = DeepLinkManager(
            placeService: services.placeService,
            userService: services.userService,
            selectedPlaceViewModel: selectedPlaceVM,
            tikTokService: services.tikTokService,
            detailPlaceViewModel: detailVM
        )
        
        let deepLinkVM = DeepLinkViewModel(
            deepLinkManager: deepLinkMgr,
            selectedPlaceViewModel: selectedPlaceVM
        )

        let profileVM = ProfileViewModel(
            userSession: userSess,
            userService: services.userService,
            detailPlaceViewModel: detailVM,
            imageService: services.imageService,
            placeService: services.placeService,
            reviewService: services.reviewService,
            locationManager: location,
            deepLinkManager: deepLinkMgr,
            deepLinkViewModel: deepLinkVM
        )
        
        let dataMgr = DataManager(
            userService: services.userService,
            placeService: services.placeService,
            reviewService: services.reviewService,
            userSession: userSess,
            locationManager: location,
            profileViewModel: profileVM,
            detailPlaceViewModel: detailVM
        )
        
        // Set DataManager reference in DetailPlaceViewModel for lazy loading
        detailVM.dataManager = dataMgr

        let userProfileVM = UserProfileViewModel(
            dataManager: dataMgr, 
            detailPlaceViewModel: detailVM,
            placeService: services.placeService,
            userService: services.userService,
            reviewService: services.reviewService
        )
        
        profileVM.userProfileViewModel = userProfileVM

        let searchVM = SearchViewModel(
            placeService: services.placeService,
            userService: services.userService,
            locationManager: location
        )
        
        let mapVM = MapViewModel(
            placeService: services.placeService,
            detailPlaceVM: detailVM
        )
        
        let placeTypeFilterVM = PlaceTypeFilterViewModel(
            detailPlaceVM: detailVM,
            profileVM: profileVM
        )
        
        // Wire up MapViewModel to PlaceTypeFilterViewModel
        placeTypeFilterVM.mapViewModel = mapVM
        
        self._locationManager = StateObject(wrappedValue: location)
        self._userSession = StateObject(wrappedValue: userSess)
        self._profileViewModel = StateObject(wrappedValue: profileVM)
        self._detailPlaceViewModel = StateObject(wrappedValue: detailVM)
        self.dataManager = dataMgr
        self._selectedPlaceViewModel = StateObject(wrappedValue: selectedPlaceVM)
        self._userProfileViewModel = StateObject(wrappedValue: userProfileVM)
        self._searchViewModel = StateObject(wrappedValue: searchVM)
        self._deepLinkManager = StateObject(wrappedValue: deepLinkMgr)
        self._deepLinkViewModel = StateObject(wrappedValue: deepLinkVM)
        self._placeTypeFilterViewModel = StateObject(wrappedValue: placeTypeFilterVM)
        self._mapViewModel = StateObject(wrappedValue: mapVM)
        
        // Pass user service to AppDelegate
        appDelegate.userService = services.userService
        appDelegate.deepLinkViewModel = deepLinkVM
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(userSession)
                .environmentObject(locationManager)
                .environmentObject(profileViewModel)
                .environmentObject(detailPlaceViewModel)
                .environmentObject(selectedPlaceViewModel)
                .environmentObject(dataManager)
                .environmentObject(userProfileViewModel)
                .environmentObject(searchViewModel)
                .environmentObject(notificationManager)
                .environmentObject(serviceContainer)
                .environmentObject(deepLinkManager)
                .environmentObject(deepLinkViewModel)
                .environmentObject(placeTypeFilterViewModel)
                .environmentObject(mapViewModel)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    // Handle deep links for places
                    if url.scheme == "loc" {
                        // Handle all deep links through DeepLinkViewModel
                        Task {
                            print("🔗 Received deep link in onOpenURL: \(url)")
                            await deepLinkViewModel.processIncomingURL(url)
                        }
                    } else {
                        print("🔗 Received non-loc deep link: \(url)")
                    }
                }
                .onContinueUserActivity("com.mesa.share.tiktok") { userActivity in
                    // Handle TikTok share via NSUserActivity
                    if let tikTokURL = userActivity.userInfo?["tikTokURL"] as? String {
                        print("🎵 Received TikTok URL via NSUserActivity: \(tikTokURL)")
                        let deepLinkURL = URL(string: "loc://share/tiktok?url=\(tikTokURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                        Task {
                            await deepLinkViewModel.processIncomingURL(deepLinkURL)
                        }
                    }
                }
                .task {
                    if let currentUser = Auth.auth().currentUser {
                        userSession.setUserLoggedIn(uid: currentUser.uid)
                        await dataManager.initializeProfileData(userId: currentUser.uid)
                    }
                    
                    // Check for shared TikTok URLs
                    checkForSharedTikTokURL()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Check again when app becomes active
                    checkForSharedTikTokURL()
                }
        }
    }
    
    private func checkForSharedTikTokURL() {
        print("🔍 Checking for shared TikTok URLs...")
        
        // Only use regular UserDefaults to avoid App Group errors
        if let regularURL = UserDefaults.standard.string(forKey: "sharedTikTokURL") {
            print("🎵 Found TikTok URL in regular UserDefaults: \(regularURL)")
            UserDefaults.standard.removeObject(forKey: "sharedTikTokURL")
            
            let deepLinkURL = URL(string: "loc://share/tiktok?url=\(regularURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            Task {
                await deepLinkViewModel.processIncomingURL(deepLinkURL)
            }
        } else {
            print("🔍 No TikTok URL found in UserDefaults")
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var userService: UserService?
    var deepLinkViewModel: DeepLinkViewModel?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Set FCM messaging delegate
        Messaging.messaging().delegate = self
        
        // Set UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions and register for remote notifications
        requestNotificationPermissions(application: application)
        
        return true
    }
    
    private func requestNotificationPermissions(application: UIApplication) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            print("🔔 Notification permission granted: \(granted)")
            if let error = error {
                print("❌ Error requesting notification permissions: \(error)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    // Register for remote notifications on main thread
                    application.registerForRemoteNotifications()
                    print("📱 Registering for remote notifications...")
                }
            } else {
                print("⚠️ User denied notification permissions")
            }
        }
    }
    
    // Called when APNs token is received
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 APNS token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        // Set APNS token for FCM
        Messaging.messaging().apnsToken = deviceToken
        
        // Now FCM can generate its token
        print("🔥 APNS token set, FCM will now generate token...")
    }
    
    // Called when registration for remote notifications fails
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // Handle Google Sign-In URLs
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        
        // Handle Apple Sign-In URLs
        if url.scheme == "drewharts.locc" {
            print("🍎 Received Apple Sign-In URL in AppDelegate: \(url)")
            return true
        }
        
        // Handle deep links for places
        if url.scheme == "loc" {
            print("🔗 Received deep link in AppDelegate: \(url)")
            Task {
                await deepLinkViewModel?.processIncomingURL(url)
            }
            return true
        } else {
            print("🔗 Received non-loc deep link in AppDelegate: \(url)")
        }
        
        return false
    }
}

// MARK: - FCM Messaging Delegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 Firebase registration token received: \(String(describing: fcmToken))")
        
        // Save the FCM token to Firestore if user is logged in
        if let fcmToken = fcmToken, let currentUserId = Auth.auth().currentUser?.uid {
            userService?.updateFCMToken(userId: currentUserId, token: fcmToken) { error in
                if let error = error {
                    print("❌ Error updating FCM token: \(error)")
                } else {
                    print("✅ FCM token successfully updated in Firestore")
                }
            }
        }
    }
}

// MARK: - User Notification Center Delegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle review notifications
        if let reviewId = userInfo["reviewId"] as? String,
           let placeId = userInfo["placeId"] as? String,
           let userId = userInfo["userId"] as? String {
            print("👆 User tapped notification for review: \(reviewId) at place: \(placeId)")
            
            // Use NotificationManager to coordinate navigation
            NotificationManager.shared.handleNotificationTap(
                reviewId: reviewId,
                placeId: placeId,
                userId: userId
            )
        }
        // Handle comment notifications  
        else if let commentId = userInfo["commentId"] as? String,
                let reviewId = userInfo["reviewId"] as? String,
                let placeId = userInfo["placeId"] as? String,
                let type = userInfo["type"] as? String,
                type == "comment" {
            print("👆 User tapped notification for comment: \(commentId) on review: \(reviewId) at place: \(placeId)")
            
            // For comments, we still navigate to the review (which will show the comments)
            // The reviewAuthorId is the person who should receive the notification
            let reviewAuthorId = userInfo["reviewAuthorId"] as? String ?? "unknown"
            
            NotificationManager.shared.handleNotificationTap(
                reviewId: reviewId,
                placeId: placeId,
                userId: reviewAuthorId
            )
        }
        
        completionHandler()
    }
}

class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}

