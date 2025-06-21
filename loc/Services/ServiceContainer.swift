import Foundation

/// Container for all app services - provides centralized service management
class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    // MARK: - Core Services
    lazy var userService = UserService.shared
    lazy var placeService = PlaceService.shared
    lazy var reviewService = ReviewService.shared
    lazy var imageService = ImageService.shared
    lazy var placeShareService = PlaceShareService()
    
    // MARK: - Managers
    lazy var locationManager = LocationManager()
    lazy var notificationManager = NotificationManager.shared
    lazy var deepLinkManager: DeepLinkManager = {
        // This will be initialized after selectedPlaceViewModel is available
        fatalError("DeepLinkManager must be initialized with selectedPlaceViewModel")
    }()
    
    private init() {
        // Private init to enforce singleton pattern
    }
    
    // MARK: - Service Dependencies Setup
    func setupServices() {
        // Any cross-service setup can go here
        // For example, if services need references to each other
    }
    
    // MARK: - Deep Link Setup
    func setupDeepLinkManager(selectedPlaceViewModel: SelectedPlaceViewModel) {
        let deepLinkManager = DeepLinkManager(
            placeService: placeService,
            selectedPlaceViewModel: selectedPlaceViewModel
        )
        
        // Use reflection to set the lazy property
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if child.label == "deepLinkManager" {
                // This is a workaround since we can't directly set a lazy property
                // We'll handle this differently
            }
        }
        
        // Store the deep link manager in a different way
        objc_setAssociatedObject(self, "deepLinkManager", deepLinkManager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    var deepLinkManagerInstance: DeepLinkManager? {
        return objc_getAssociatedObject(self, "deepLinkManager") as? DeepLinkManager
    }
} 