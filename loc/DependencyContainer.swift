import Foundation
import SwiftUI

/// This class will manage the creation and dependencies of your services and view models.
class DependencyContainer {

    // MARK: - Services (using singletons as in original code)
    let userService: UserService
    let placeService: PlaceService
    let reviewService: ReviewService
    let imageService: ImageService
    
    // MARK: - App-wide State Managers
    let locationManager: LocationManager
    let userSession: UserSession
    let dataManager: DataManager
    let notificationManager: NotificationManager
    
    // MARK: - View Models
    let detailPlaceViewModel: DetailPlaceViewModel
    let profileViewModel: ProfileViewModel
    let selectedPlaceViewModel: SelectedPlaceViewModel
    let userProfileViewModel: UserProfileViewModel

    init() {
        // Services
        self.userService = UserService.shared
        self.placeService = PlaceService.shared
        self.reviewService = ReviewService.shared
        self.imageService = ImageService.shared
        self.notificationManager = NotificationManager.shared
        
        // Managers
        self.locationManager = LocationManager()
        
        // View Models (order is important to resolve dependencies)
        self.detailPlaceViewModel = DetailPlaceViewModel(placeService: self.placeService, reviewService: self.reviewService, imageService: self.imageService, userService: self.userService)
        self.userSession = UserSession(userService: self.userService, locationManager: self.locationManager, detailPlaceVM: self.detailPlaceViewModel)
        self.profileViewModel = ProfileViewModel(userSession: self.userSession, userService: self.userService, detailPlaceViewModel: self.detailPlaceViewModel, imageService: self.imageService, placeService: self.placeService, reviewService: self.reviewService)
        self.selectedPlaceViewModel = SelectedPlaceViewModel(locationManager: self.locationManager, placeService: self.placeService)
        
        // DataManager
        // Note: DataManager has many dependencies, including other view models.
        self.dataManager = DataManager(
            userService: self.userService,
            placeService: self.placeService,
            reviewService: self.reviewService,
            userSession: self.userSession,
            locationManager: self.locationManager,
            profileViewModel: self.profileViewModel,
            detailPlaceViewModel: self.detailPlaceViewModel
        )

        self.userProfileViewModel = UserProfileViewModel(dataManager: self.dataManager, detailPlaceViewModel: self.detailPlaceViewModel)
    }
} 