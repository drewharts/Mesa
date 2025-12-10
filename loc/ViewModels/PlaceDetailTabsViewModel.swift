//
//  PlaceDetailTabsViewModel.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Proper MVVM implementation - One View, One ViewModel
//

import Foundation
import SwiftUI
import CoreLocation
import Combine

// MARK: - Tab Type
enum DetailTab {
    case about
    case reviews
    case notes
}

@MainActor
class PlaceDetailTabsViewModel: ObservableObject {
    // MARK: - Dependencies (Services, not other ViewModels)
    private let placeService: PlaceService
    private let reviewService: ReviewService
    private let userService: UserService
    private let notificationManager: NotificationManager
    
    // Reference to shared state (temporary until fully refactored)
    private let selectedPlaceVM: SelectedPlaceViewModel
    private let profileVM: ProfileViewModel
    
    // MARK: - Child ViewModels
    let aboutTabViewModel: AboutTabViewModel
    let notesTabViewModel: NotesTabViewModel
    let reviewsViewModel: PlaceReviewsViewModel
    let travelTimeViewModel: TravelTimeViewModel
    var placeSaversViewModel: PlaceSaversViewModel
    
    // MARK: - Published Properties (What the View Needs)
    @Published var placeName: String = "Loading..."
    @Published var restaurantType: String?
    @Published var isCustomPlace: Bool = false
    @Published var placeRating: Double = 0.0
    @Published var hasReviews: Bool = false
    @Published var reviewCount: Int = 0
    @Published var selectedTab: DetailTab = .about
    @Published var showMaxFavoritesAlert: Bool = false
    @Published var currentPlace: DetailPlace?
    
    // Forwarded from PlaceSaversViewModel (enables view re-render when savers change)
    @Published var showSaversIndicator: Bool = false
    @Published var saverCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(placeService: PlaceService,
         reviewService: ReviewService,
         userService: UserService,
         notificationManager: NotificationManager,
         selectedPlaceVM: SelectedPlaceViewModel,
         profileVM: ProfileViewModel,
         userSession: UserSession,
         detailPlaceViewModel: DetailPlaceViewModel) {
        self.placeService = placeService
        self.reviewService = reviewService
        self.userService = userService
        self.notificationManager = notificationManager
        self.selectedPlaceVM = selectedPlaceVM
        self.profileVM = profileVM
        
        // Create child ViewModels
        let tikTokVM = TikTokVideosViewModel(
            tikTokService: TikTokPlaceService.shared,
            selectedPlaceVM: selectedPlaceVM,
            profileVM: profileVM
        )
        
        let photosVM = PlacePhotosViewModel(
            reviewService: reviewService,
            selectedPlaceVM: selectedPlaceVM
        )
        
        let customPlaceCreatorVM = CustomPlaceCreatorViewModel(
            placeService: placeService
        )
        
        self.aboutTabViewModel = AboutTabViewModel(
            tikTokVideosViewModel: tikTokVM,
            placePhotosViewModel: photosVM,
            customPlaceCreatorViewModel: customPlaceCreatorVM,
            selectedPlaceVM: selectedPlaceVM
        )
        
        self.notesTabViewModel = NotesTabViewModel(
            userService: userService,
            selectedPlaceVM: selectedPlaceVM,
            profileVM: profileVM,
            userSession: userSession
        )
        
        self.reviewsViewModel = PlaceReviewsViewModel(
            reviewService: reviewService,
            photosViewModel: photosVM,
            selectedPlaceVM: selectedPlaceVM,
            notificationManager: notificationManager,
            userSession: userSession
        )
        
        self.travelTimeViewModel = TravelTimeViewModel(
            selectedPlaceVM: selectedPlaceVM
        )
        
        self.placeSaversViewModel = PlaceSaversViewModel(
            userService: userService,
            detailPlaceViewModel: detailPlaceViewModel,
            userSession: userSession
        )
        
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe selected place changes
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                self?.handlePlaceChanged(place)
            }
            .store(in: &cancellables)
        
        // Observe reviews changes
        selectedPlaceVM.$selectedPlace
            .combineLatest(selectedPlaceVM.$placeRating)
            .sink { [weak self] place, rating in
                guard let self = self else { return }
                self.placeRating = rating
                self.hasReviews = !self.selectedPlaceVM.reviews.isEmpty
                self.reviewCount = self.selectedPlaceVM.reviews.count
            }
            .store(in: &cancellables)
        
        // Observe notification highlights
        notificationManager.$highlightedReviewId
            .sink { [weak self] reviewId in
                if reviewId != nil {
                    self?.selectedTab = .reviews
                }
            }
            .store(in: &cancellables)
        
        // Observe favorites alert
        profileVM.$showMaxFavoritesAlert
            .assign(to: &$showMaxFavoritesAlert)
        
        // Forward PlaceSaversViewModel state to trigger view updates
        // IMPORTANT: Set up this observer BEFORE the place observer so state is forwarded correctly
        // This is necessary because child VM changes don't automatically trigger parent view re-render
        placeSaversViewModel.$totalSaverCount
            .sink { [weak self] count in
                self?.saverCount = count
                self?.showSaversIndicator = count > 0
            }
            .store(in: &cancellables)
        
        // Update placeSaversViewModel when place changes
        // This fires immediately with current value, so saver count observer above must be set up first
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                self?.placeSaversViewModel.setPlace(place?.id.uuidString)
            }
            .store(in: &cancellables)
    }
    
    /// Configure savers VM with navigation dependency (call from View)
    func configureSaversViewModel(userProfileViewModel: UserProfileViewModel) {
        placeSaversViewModel.configure(userProfileViewModel: userProfileViewModel)
    }
    
    private func handlePlaceChanged(_ place: DetailPlace?) {
        currentPlace = place
        placeName = place?.name ?? "Loading..."
        isCustomPlace = place?.isCustom == true
        
        if let place = place {
            // Custom places show "Custom" as type, others use category-based type
            if place.isCustom == true {
                restaurantType = "Custom"
            } else {
                restaurantType = getRestaurantType(for: place)
            }
        } else {
            restaurantType = nil
        }
        
        // Set default tab based on reviews
        if selectedPlaceVM.reviews.isEmpty {
            selectedTab = .about
        }
    }
    
    // Travel time management delegated to TravelTimeViewModel
    // MARK: - Actions (What the View Can Trigger)
    func selectTab(_ tab: DetailTab) {
        selectedTab = tab
    }
    
    func openGoogleMaps() {
        guard let place = currentPlace else { return }
        let name = place.name
        
        let query: String
        if let address = place.address {
            query = "\(name), \(address)"
        } else if let latitude = place.coordinate?.latitude,
                  let longitude = place.coordinate?.longitude {
            query = "\(name) @\(latitude),\(longitude)"
        } else {
            query = name
        }
        
        openGoogleMapsWithPlace(query: query)
    }
    
    func onAppear() {
        // Load review photos for about section (handled by PlacePhotosViewModel)
        // PlacePhotosViewModel automatically loads review photos when place changes
    }
    
    // MARK: - Private Helpers
    private func getRestaurantType(for place: DetailPlace) -> String? {
        guard let placeTypes = place.categories, !placeTypes.isEmpty else {
            return PlaceTypes.defaultType
        }
        
        let placeTypesCopy = Array(placeTypes)
        let recognizedTypesCopy = Array(PlaceTypes.recognizedTypes)
        
        // Generic terms to skip in first pass
        let genericTerms = [
            "Restaurant", "Cafe", "Bar", "Place",
            "Point of Interest", "Point Of Interest", "Point_of_Interest",
            "POI", "Establishment", "Store", "Business", "Location",
            "Venue", "Site", "Spot", "Destination"
        ]
        
        // First pass: Look for specific cuisine types
        for recognizedType in recognizedTypesCopy {
            let normalizedRecognizedType = recognizedType.lowercased()
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: ".", with: " ")
            
            let isGenericTerm = genericTerms.contains { genericTerm in
                let normalizedGenericTerm = genericTerm.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                return normalizedRecognizedType == normalizedGenericTerm
            }
            
            if isGenericTerm { continue }
            
            guard !recognizedType.isEmpty else { continue }
            
            if placeTypesCopy.contains(where: { placeType in
                guard !placeType.isEmpty else { return false }
                
                let normalizedPlaceType = placeType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                let normalizedRecognizedType = recognizedType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                guard !normalizedPlaceType.isEmpty && !normalizedRecognizedType.isEmpty else {
                    return false
                }
                
                return normalizedPlaceType.contains(normalizedRecognizedType)
            }) {
                return recognizedType
            }
        }
        
        // Second pass: Look for generic terms if no specific type found
        for genericTerm in genericTerms {
            if placeTypesCopy.contains(where: { placeType in
                guard !placeType.isEmpty else { return false }
                
                let normalizedPlaceType = placeType.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                let normalizedGenericTerm = genericTerm.lowercased()
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                
                guard !normalizedPlaceType.isEmpty && !normalizedGenericTerm.isEmpty else {
                    return false
                }
                
                return normalizedPlaceType.contains(normalizedGenericTerm)
            }) {
                return genericTerm
            }
        }
        
        return PlaceTypes.defaultType
    }
    
    private func openGoogleMapsWithPlace(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let googleMapsURL = URL(string: "comgooglemaps://?q=\(encodedQuery)") else { return }
        let fallbackURL = URL(string: "https://maps.google.com/?q=\(encodedQuery)")!
        
        if UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.open(fallbackURL, options: [:], completionHandler: nil)
        }
    }
}

