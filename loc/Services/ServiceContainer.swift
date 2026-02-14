import Foundation

/// Container for all app services - provides centralized service management
@MainActor
class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    // MARK: - Supabase Services (actively fetching from Supabase)
    lazy var authService = SupabaseAuthService.shared
    lazy var supabaseUserService = SupabaseUserService.shared
    lazy var supabasePlaceService = SupabasePlaceService.shared
    lazy var supabasePostService = SupabasePostService.shared
    lazy var realtimeService = SupabaseRealtimeService.shared
    
    // MARK: - Legacy Service Wrappers (for ViewModel compatibility - delegate to Supabase)
    lazy var userService: UserService = UserService.shared
    lazy var placeService: PlaceService = PlaceService.shared
    lazy var postService: PostService = PostService.shared
    
    // MARK: - Other Services (unchanged)
    lazy var imageService = ImageService.shared
    lazy var placeShareService = PlaceShareService()
    lazy var tikTokService = TikTokService()
    lazy var collaborationService = CollaborationService.shared

    // MARK: - Cache Services
    lazy var postsCacheService = PlacePostsCacheService.shared

    // MARK: - Repositories
    lazy var placeRepository = PlaceRepository.shared

    // MARK: - Presentation Service (centralized sheet/modal management)
    let presentationService = PresentationService.shared
    
    // MARK: - Managers
    lazy var locationManager = LocationManager()
    lazy var notificationManager = NotificationManager.shared
    lazy var pushNotificationService = PushNotificationService.shared
    lazy var deepLinkManager: DeepLinkManager = {
        let dummyLocationManager = LocationManager()
        let dummySelectedPlaceVM = SelectedPlaceViewModel(
            locationManager: dummyLocationManager,
            postService: self.postService,
            placeService: self.placeService,
            userService: self.userService,
            imageService: self.imageService
        )
        let dummyDetailPlaceVM = DetailPlaceViewModel(
            placeService: self.placeService,
            userService: self.userService
        )

        return DeepLinkManager(
            placeService: self.placeService,
            userService: self.userService,
            selectedPlaceViewModel: dummySelectedPlaceVM,
            tikTokService: self.tikTokService,
            detailPlaceViewModel: dummyDetailPlaceVM
        )
    }()
    
    private init() {
        // Private init to enforce singleton pattern
    }
    
    // MARK: - Service Dependencies Setup
    func setupServices() {
        // Any cross-service setup can go here
        // For example, if services need references to each other
    }
} 