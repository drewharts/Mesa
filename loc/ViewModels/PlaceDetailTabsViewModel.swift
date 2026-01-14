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
}

@MainActor
class PlaceDetailTabsViewModel: ObservableObject {
    // MARK: - Dependencies (Services, not other ViewModels)
    private let placeService: PlaceService
    private let postService: PostService
    private let userService: UserService
    private let notificationManager: NotificationManager
    private let placeShareService: PlaceShareService
    
    // Reference to shared state (temporary until fully refactored)
    private let selectedPlaceVM: SelectedPlaceViewModel
    private let profileVM: ProfileViewModel
    private let detailPlaceViewModel: DetailPlaceViewModel
    private let userSession: UserSession
    private let placeListService = PlaceListService.shared
    
    // MARK: - Child ViewModels
    let aboutTabViewModel: AboutTabViewModel
    let notesTabViewModel: NotesTabViewModel
    let postsViewModel: PlacePostsViewModel
    let travelTimeViewModel: TravelTimeViewModel
    let openStatusViewModel: OpenStatusViewModel
    var placeSaversViewModel: PlaceSaversViewModel
    
    // MARK: - Published Properties (What the View Needs)
    @Published var placeName: String = "Loading..."
    @Published var restaurantType: String?
    @Published var isCustomPlace: Bool = false
    @Published var placeRating: Double = 0.0
    @Published var hasPosts: Bool = false
    @Published var postCount: Int = 0
    @Published var selectedTab: DetailTab = .about
    @Published var showMaxFavoritesAlert: Bool = false
    @Published var currentPlace: DetailPlace?
    
    // Forwarded from PlaceSaversViewModel (enables view re-render when savers change)
    @Published var showSaversIndicator: Bool = false
    @Published var saverCount: Int = 0
    
    // Forwarded from OpenStatusViewModel (enables view re-render when status changes)
    @Published var openStatus: OpenStatus = .unknown
    
    // MARK: - Place Actions State
    /// Whether the current place is saved in any of the user's lists
    @Published var isPlaceInList: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(placeService: PlaceService,
         postService: PostService,
         userService: UserService,
         notificationManager: NotificationManager,
         placeShareService: PlaceShareService,
         selectedPlaceVM: SelectedPlaceViewModel,
         profileVM: ProfileViewModel,
         userSession: UserSession,
         detailPlaceViewModel: DetailPlaceViewModel) {
        self.placeService = placeService
        self.postService = postService
        self.userService = userService
        self.notificationManager = notificationManager
        self.placeShareService = placeShareService
        self.selectedPlaceVM = selectedPlaceVM
        self.profileVM = profileVM
        self.detailPlaceViewModel = detailPlaceViewModel
        self.userSession = userSession
        
        // Create child ViewModels
        let tikTokVM = TikTokVideosViewModel(
            tikTokService: TikTokPlaceService.shared,
            selectedPlaceVM: selectedPlaceVM,
            profileVM: profileVM
        )
        
        let photosVM = PlacePhotosViewModel(
            postService: postService,
            selectedPlaceVM: selectedPlaceVM
        )
        
        let customPlaceCreatorVM = CustomPlaceCreatorViewModel(
            placeService: placeService
        )
        
        self.notesTabViewModel = NotesTabViewModel(
            userService: userService,
            selectedPlaceVM: selectedPlaceVM,
            profileVM: profileVM,
            userSession: userSession
        )
        
        self.aboutTabViewModel = AboutTabViewModel(
            tikTokVideosViewModel: tikTokVM,
            placePhotosViewModel: photosVM,
            customPlaceCreatorViewModel: customPlaceCreatorVM,
            notesViewModel: self.notesTabViewModel,
            selectedPlaceVM: selectedPlaceVM
        )
        
        self.postsViewModel = PlacePostsViewModel(
            postService: postService,
            photosViewModel: photosVM,
            selectedPlaceVM: selectedPlaceVM,
            notificationManager: notificationManager,
            userSession: userSession,
            profileVM: profileVM
        )
        
        self.travelTimeViewModel = TravelTimeViewModel(
            selectedPlaceVM: selectedPlaceVM
        )
        
        self.openStatusViewModel = OpenStatusViewModel(
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
        
        // Observe posts changes
        selectedPlaceVM.$selectedPlace
            .combineLatest(selectedPlaceVM.$placeRating)
            .sink { [weak self] place, rating in
                guard let self = self else { return }
                self.placeRating = rating
                self.hasPosts = !self.selectedPlaceVM.posts.isEmpty
                self.postCount = self.selectedPlaceVM.posts.count
            }
            .store(in: &cancellables)
        
        // Observe notification highlights
        notificationManager.$highlightedReviewId
            .sink { [weak self] postId in
                if postId != nil {
                    self?.selectedTab = .reviews
                }
            }
            .store(in: &cancellables)
        
        // Observe favorites alert - only forward when becoming true to avoid loops
        profileVM.$showMaxFavoritesAlert
            .filter { $0 == true }
            .sink { [weak self] _ in
                self?.showMaxFavoritesAlert = true
            }
            .store(in: &cancellables)
        
        // Forward PlaceSaversViewModel state to trigger view updates
        // IMPORTANT: Set up this observer BEFORE the place observer so state is forwarded correctly
        // This is necessary because child VM changes don't automatically trigger parent view re-render
        placeSaversViewModel.$totalSaverCount
            .sink { [weak self] count in
                self?.saverCount = count
                self?.showSaversIndicator = count > 0
            }
            .store(in: &cancellables)
        
        // Forward OpenStatusViewModel state to trigger view updates
        // This is necessary because child VM changes don't automatically trigger parent view re-render
        openStatusViewModel.$status
            .sink { [weak self] status in
                self?.openStatus = status
            }
            .store(in: &cancellables)
        
        // Update placeSaversViewModel when place changes
        // This fires immediately with current value, so saver count observer above must be set up first
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                self?.placeSaversViewModel.setPlace(place?.id.uuidString)
            }
            .store(in: &cancellables)
        
        // Check place list membership when place changes (database source of truth)
        // SQL function only checks place_list_items, not external_places (TikToks)
        selectedPlaceVM.$selectedPlace
            .sink { [weak self] place in
                guard let self = self else { return }
                Task {
                    await self.checkPlaceListMembership(place: place)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check if the current place is saved in any of the user's lists (database call)
    /// Only checks place_list_items table, NOT external_places (TikToks)
    private func checkPlaceListMembership(place: DetailPlace?) async {
        guard let place = place, let userId = userSession.currentUserId else {
            isPlaceInList = false
            return
        }
        
        do {
            let isSaved = try await placeListService.isPlaceInAnyUserList(
                userId: userId,
                placeId: place.id.uuidString
            )
            isPlaceInList = isSaved
        } catch {
            print("❌ [PlaceDetailTabsVM] Error checking place list membership: \(error)")
            // On error, default to false (don't show bookmark as filled)
            isPlaceInList = false
        }
    }

    /// Public method to refresh list membership state (call after saving to list)
    func refreshPlaceListMembership() {
        Task {
            await checkPlaceListMembership(place: selectedPlaceVM.selectedPlace)
        }
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
            // For custom places, view shows "Created by [photo]" instead of type
            // Still compute type in case we want to show both in the future
            restaurantType = getRestaurantType(for: place)
        } else {
            restaurantType = nil
        }
        
        // Set default tab based on posts
        if selectedPlaceVM.posts.isEmpty {
            selectedTab = .about
        }
    }
    
    // Travel time management delegated to TravelTimeViewModel
    // MARK: - Actions (What the View Can Trigger)
    func selectTab(_ tab: DetailTab) {
        selectedTab = tab
    }
    
    /// Shares the current place using the system share sheet
    func sharePlace() {
        guard let place = currentPlace else { return }
        placeShareService.sharePlace(place)
    }
    
    /// Resets the max favorites alert state in both this ViewModel and the source ProfileViewModel
    func dismissMaxFavoritesAlert() {
        showMaxFavoritesAlert = false
        profileVM.showMaxFavoritesAlert = false
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

