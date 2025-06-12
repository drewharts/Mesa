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
    
    private let container: DependencyContainer

    @StateObject private var locationManager: LocationManager
    @StateObject private var userSession: UserSession
    @StateObject private var profileViewModel: ProfileViewModel
    @StateObject private var detailPlaceViewModel: DetailPlaceViewModel
    @StateObject private var selectedPlaceViewModel: SelectedPlaceViewModel
    @StateObject private var userProfileViewModel: UserProfileViewModel
    @StateObject private var notificationManager: NotificationManager
    @StateObject private var dataManager: DataManager
    
    // Services are also ObservableObjects and should be managed as state.
    @StateObject private var userService: UserService
    @StateObject private var placeService: PlaceService
    @StateObject private var reviewService: ReviewService
    @StateObject private var imageService: ImageService

    init() {
        FirebaseApp.configure()
        let providerFactory = AppAttestProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Create the dependency container
        let container = DependencyContainer()
        self.container = container
        
        // Initialize all @StateObject properties from the container
        self._locationManager = StateObject(wrappedValue: container.locationManager)
        self._userSession = StateObject(wrappedValue: container.userSession)
        self._profileViewModel = StateObject(wrappedValue: container.profileViewModel)
        self._detailPlaceViewModel = StateObject(wrappedValue: container.detailPlaceViewModel)
        self._selectedPlaceViewModel = StateObject(wrappedValue: container.selectedPlaceViewModel)
        self._userProfileViewModel = StateObject(wrappedValue: container.userProfileViewModel)
        self._notificationManager = StateObject(wrappedValue: container.notificationManager)
        self._dataManager = StateObject(wrappedValue: container.dataManager)
        
        self._userService = StateObject(wrappedValue: container.userService)
        self._placeService = StateObject(wrappedValue: container.placeService)
        self._reviewService = StateObject(wrappedValue: container.reviewService)
        self._imageService = StateObject(wrappedValue: container.imageService)
        
        // Pass user service to AppDelegate
        appDelegate.userService = container.userService
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
                .environmentObject(notificationManager)
                .environmentObject(userService)
                .environmentObject(placeService)
                .environmentObject(reviewService)
                .environmentObject(imageService)
                .preferredColorScheme(.light)
                .task {
                    if let currentUser = Auth.auth().currentUser {
                        userSession.isUserLoggedIn = true
                        userSession.currentUserId = currentUser.uid
                        await dataManager.initializeProfileData(userId: currentUser.uid)
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var userService: UserService?

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
        return GIDSignIn.sharedInstance.handle(url)
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
