import SwiftUI
import GoogleSignIn
import UserNotifications
import Supabase

@main
struct locApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Only 3 global environment objects!
    @StateObject private var locationManager: LocationManager
    @StateObject private var userSession: UserSession
    @StateObject private var appCoordinator = AppCoordinator()
    
    // Other dependencies (not environment objects)
    private let serviceContainer = ServiceContainer.shared
    private let selectedPlaceViewModel: SelectedPlaceViewModel
    private let profileViewModel: ProfileViewModel
    private let userProfileViewModel: UserProfileViewModel
    private let detailPlaceViewModel: DetailPlaceViewModel
    private let deepLinkViewModel: DeepLinkViewModel
    private let deepLinkManager: DeepLinkManager
    private let notificationManager = NotificationManager.shared
    private let dataManager: DataManager
    private let searchViewModel: SearchViewModel  // ✅ Staff Engineer: Create VM at app level
    private let searchCoordinator: SearchCoordinatorViewModel  // ✅ Coordinator for search interactions
    
    init() {
        // Supabase is initialized via SupabaseManager.shared
        
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
            imageService: services.imageService,
            detailPlaceViewModel: detailVM
        )
        
        let deepLinkMgr = DeepLinkManager(
            placeService: services.placeService,
            userService: services.userService,
            selectedPlaceViewModel: selectedPlaceVM,
            tikTokService: services.tikTokService,
            detailPlaceViewModel: detailVM,
            profileViewModel: nil // Will be set after ProfileViewModel is created
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
        
        // Set ProfileViewModel reference in DeepLinkManager so it can create external_place entries
        deepLinkMgr.setProfileViewModel(profileVM)
        
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
        
        // ✅ Create SearchViewModel ONCE at app level (staff engineer: no recreation overhead)
        let searchVM = SearchViewModel(
            placeService: services.placeService,
            userService: services.userService,
            locationManager: location
        )
        
        // ✅ Create SearchCoordinator to handle search interactions (MVVM Coordinator Pattern)
        let searchCoord = SearchCoordinatorViewModel(
            selectedPlaceVM: selectedPlaceVM,
            userProfileViewModel: userProfileVM,
            userSession: userSess
        )
        
        // Assign to properties
        self._locationManager = StateObject(wrappedValue: location)
        self._userSession = StateObject(wrappedValue: userSess)
        self.selectedPlaceViewModel = selectedPlaceVM
        self.profileViewModel = profileVM
        self.userProfileViewModel = userProfileVM
        self.detailPlaceViewModel = detailVM
        self.deepLinkViewModel = deepLinkVM
        self.deepLinkManager = deepLinkMgr
        self.dataManager = dataMgr
        self.searchViewModel = searchVM
        self.searchCoordinator = searchCoord
        
        // Pass user service to AppDelegate
        appDelegate.userService = services.userService
        appDelegate.deepLinkViewModel = deepLinkVM
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView(
                selectedPlaceViewModel: selectedPlaceViewModel,
                profileViewModel: profileViewModel,
                userProfileViewModel: userProfileViewModel,
                detailPlaceViewModel: detailPlaceViewModel,
                deepLinkViewModel: deepLinkViewModel,
                deepLinkManager: deepLinkManager,
                notificationManager: notificationManager,
                dataManager: dataManager,
                serviceContainer: serviceContainer,
                searchViewModel: searchViewModel,  // ✅ Pass to children
                searchCoordinator: searchCoordinator  // ✅ Pass coordinator
            )
                // Only 3 environment objects at the root!
                .environmentObject(userSession)
                .environmentObject(locationManager)
                .environmentObject(appCoordinator)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    // Handle deep links (loc:// scheme)
                    if url.scheme == "loc" {
                        Task {
                            await deepLinkViewModel.processIncomingURL(url)
                        }
                    }
                    // Handle Universal Links (https:// from our domain)
                    else if url.scheme == "https" && url.host == "mesa-backend-staging.up.railway.app" {
                        if let deepLinkURL = convertUniversalLinkToDeepLink(url) {
                            Task {
                                await deepLinkViewModel.processIncomingURL(deepLinkURL)
                            }
                        }
                    }
                }
                .onContinueUserActivity("com.mesa.share.tiktok") { userActivity in
                    // Handle TikTok share via NSUserActivity
                    if let tikTokURL = userActivity.userInfo?["tikTokURL"] as? String {
                        let deepLinkURL = URL(string: "loc://share/tiktok?url=\(tikTokURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
                        Task {
                            await deepLinkViewModel.processIncomingURL(deepLinkURL)
                        }
                    }
                }
                .onAppear {
                    // Check for shared TikTok URLs on app launch
                    checkForSharedTikTokURL()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Check for shared TikTok URLs when app becomes active
                    checkForSharedTikTokURL()
                }
        }
    }
    
    private func checkForSharedTikTokURL() {
        // Check App Group first (preferred method)
        if let sharedDefaults = UserDefaults(suiteName: "group.com.drewhartsfield.mesa"),
           let appGroupURL = sharedDefaults.string(forKey: "sharedTikTokURL") {
            sharedDefaults.removeObject(forKey: "sharedTikTokURL")
            sharedDefaults.synchronize()
            
            print("🔗 [locApp] Found TikTok URL in App Group: \(appGroupURL)")
            processSharedTikTokURL(appGroupURL)
            return
        }
        
        // Fallback: Check standard UserDefaults
        if let standardURL = UserDefaults.standard.string(forKey: "sharedTikTokURL") {
            UserDefaults.standard.removeObject(forKey: "sharedTikTokURL")
            UserDefaults.standard.synchronize()
            
            print("🔗 [locApp] Found TikTok URL in standard UserDefaults: \(standardURL)")
            processSharedTikTokURL(standardURL)
        }
    }
    
    private func processSharedTikTokURL(_ urlString: String) {
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let deepLinkURL = URL(string: "loc://share/tiktok?url=\(encodedURL)") else {
            print("❌ [locApp] Failed to create deep link URL from: \(urlString)")
            return
        }
        
        Task {
            await deepLinkViewModel.processIncomingURL(deepLinkURL)
        }
    }
    
    /// Converts a Universal Link URL to the internal deep link format
    /// Example: https://mesa-backend-staging.up.railway.app/place/abc123?name=... -> loc://place/abc123?name=...
    private func convertUniversalLinkToDeepLink(_ url: URL) -> URL? {
        let path = url.path
        
        guard let incomingComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        if path.hasPrefix("/place/") {
            let placeId = String(path.dropFirst("/place/".count))
            
            var deepLinkComponents = URLComponents()
            deepLinkComponents.scheme = "loc"
            deepLinkComponents.host = "place"
            deepLinkComponents.path = "/\(placeId)"
            deepLinkComponents.queryItems = incomingComponents.queryItems
            
            return deepLinkComponents.url
            
        } else if path.hasPrefix("/list/") {
            let listId = String(path.dropFirst("/list/".count))
            
            var deepLinkComponents = URLComponents()
            deepLinkComponents.scheme = "loc"
            deepLinkComponents.host = "list"
            deepLinkComponents.path = "/\(listId)"
            deepLinkComponents.queryItems = incomingComponents.queryItems
            
            return deepLinkComponents.url
        }
        
        return nil
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var userService: UserService?
    var deepLinkViewModel: DeepLinkViewModel?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Set UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions and register for remote notifications
        requestNotificationPermissions(application: application)
        
        return true
    }
    
    private func requestNotificationPermissions(application: UIApplication) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("❌ Error requesting notification permissions: \(error)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    // Register for remote notifications on main thread
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ User denied notification permissions")
            }
        }
    }
    
    // Called when APNs token is received
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // TODO: Implement push notifications
        // You can use this token for APNs directly or another push service
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
            return true
        }
        
        // Handle deep links for places
        if url.scheme == "loc" {
            Task {
                await deepLinkViewModel?.processIncomingURL(url)
            }
            return true
        }
        
        return false
    }
}

// MARK: - Push Notifications (FCM removed)
// TODO: Implement alternative push notification system (APNs, OneSignal, etc.)

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

// Using Supabase for all backend services

