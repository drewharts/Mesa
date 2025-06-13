import Foundation

/// Container for all app services - provides centralized service management
class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    // MARK: - Core Services
    lazy var userService = UserService.shared
    lazy var placeService = PlaceService.shared
    lazy var reviewService = ReviewService.shared
    lazy var imageService = ImageService.shared
    
    // MARK: - Managers
    lazy var locationManager = LocationManager()
    lazy var notificationManager = NotificationManager.shared
    
    private init() {
        // Private init to enforce singleton pattern
    }
    
    // MARK: - Service Dependencies Setup
    func setupServices() {
        // Any cross-service setup can go here
        // For example, if services need references to each other
    }
} 