import Foundation

/// Container for all app services - provides centralized service management
@MainActor
class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    // MARK: - Supabase Services (actively fetching from Supabase)
    lazy var authService = SupabaseAuthService.shared
    lazy var supabaseUserService = SupabaseUserService.shared
    lazy var supabasePlaceService = SupabasePlaceService.shared
    lazy var supabaseReviewService = SupabaseReviewService.shared
    lazy var realtimeService = SupabaseRealtimeService.shared
    
    // MARK: - Legacy Service Wrappers (for ViewModel compatibility - delegate to Supabase)
    lazy var userService: UserService = UserService.shared
    lazy var placeService: PlaceService = PlaceService.shared
    lazy var reviewService: ReviewService = ReviewService.shared
    
    // MARK: - Other Services (unchanged)
    lazy var imageService = ImageService.shared
    lazy var placeShareService = PlaceShareService()
    lazy var tikTokService = TikTokService()
    
    // MARK: - Managers
    lazy var locationManager = LocationManager()
    lazy var notificationManager = NotificationManager.shared
    lazy var deepLinkManager: DeepLinkManager = {
        let dummyLocationManager = LocationManager()
        let dummySelectedPlaceVM = SelectedPlaceViewModel(
            locationManager: dummyLocationManager,
            reviewService: self.reviewService,
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