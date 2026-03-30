//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var placeVM: DetailPlaceViewModel
    @EnvironmentObject var userProfileNavigationViewModel: UserProfileNavigationViewModel
    @EnvironmentObject var mapDisplayCoordinatorViewModel: MapDisplayCoordinatorViewModel
    @EnvironmentObject var deepLinkViewModel: DeepLinkViewModel
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var serviceContainer: ServiceContainer
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var photoImportVM = PhotoImportViewModel()
    @StateObject private var externalContentService = ExternalContentService()

    /// Convenience accessor for external content view model.
    private var externalContentVM: ProfileExternalContentViewModel { profile.externalContentViewModel }

    @State private var showCreatePost = false
    @State private var postWasSubmitted = false

    // Track if we've already done initial data refresh
    @State private var hasRefreshedPlaces = false

    // Navigation path for followers/following lists
    @State private var navigationPath = NavigationPath()

    init() {
        // Configure navigation bar appearance to remove the bottom border
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground() // Use opaque background
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .navigationBarBackButtonHidden(true)
                .preferredColorScheme(.light)
                .navigationBarTitleDisplayMode(.inline)
                .modifier(ToolbarModifier(
                    presentationMode: presentationMode,
                    photoImportVM: photoImportVM,
                    profile: profile
                ))
                .navigationDestination(for: FollowListDestination.self) { destination in
                    // Navigate to followers or following list
                    // MVVM: View coordinates navigation based on destination
                    Group {
                        switch destination {
                        case .followers:
                            FollowersListView(socialVM: profile.socialViewModel)
                                .environmentObject(profile)
                                .environmentObject(userProfileNavigationViewModel)
                                .environmentObject(dataManager)
                                .environmentObject(userSession)
                                .environmentObject(placeVM)
                                .environmentObject(selectedPlaceVM)
                        case .following:
                            FollowingListView(socialVM: profile.socialViewModel)
                                .environmentObject(profile)
                                .environmentObject(userProfileNavigationViewModel)
                                .environmentObject(dataManager)
                                .environmentObject(userSession)
                                .environmentObject(placeVM)
                                .environmentObject(selectedPlaceVM)
                        }
                    }
                }
        }
            .modifier(SheetsModifier(
                photoImportVM: photoImportVM,
                profile: profile,
                placeVM: placeVM,
                externalContentVM: profile.externalContentViewModel,
                showCreatePost: $showCreatePost,
                postWasSubmitted: $postWasSubmitted
            ))
            .modifier(StateChangesModifier(
                photoImportVM: photoImportVM,
                profile: profile,
                placeVM: placeVM,
                showCreatePost: $showCreatePost,
                postWasSubmitted: $postWasSubmitted,
                externalContentService: externalContentService,
                hasRefreshedPlaces: $hasRefreshedPlaces
            ))
            .alert("No Location Found", isPresented: $deepLinkViewModel.showNoLocationAlert) {
                Button("OK") {
                    deepLinkViewModel.dismissNoLocationAlert()
                }
            } message: {
                Text(deepLinkViewModel.noLocationAlertMessage)
            }
            .sheet(isPresented: Binding(
                get: { externalContentVM.isShowingNoPlacesFound },
                set: { externalContentVM.isShowingNoPlacesFound = $0 }
            )) {
                NoPlacesFoundView(contentUrl: externalContentVM.noPlacesFoundContentUrl)
                    .environmentObject(profile)
                    .environmentObject(userSession)
                    .environmentObject(placeVM)
                    .presentationDragIndicator(.visible)
            }
            // Staff Engineer: Reactive logout - dismiss fullScreenCover when user logs out
            .onChange(of: userSession.isUserLoggedIn) { _, isLoggedIn in
                if !isLoggedIn {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .modifier(AccountManagementModifier(accountViewModel: profile.accountViewModel))
    }
    
    /// Navigation destination enum for followers/following lists
    /// Single Responsibility: Defines navigation destinations for follow lists
    enum FollowListDestination: Hashable {
        case followers
        case following
    }
    
    private var mainContent: some View {
        ZStack {
            // Main Content
            ProfileContentView(
                socialVM: profile.socialViewModel,
                myPlacesVM: profile.myPlacesViewModel,
                favoritesVM: profile.favoritesViewModel,
                externalContentVM: profile.externalContentViewModel,
                reviewsVM: profile.reviewsViewModel,
                listsVM: profile.listsViewModel,
                photoImportVM: photoImportVM,
                navigationPath: $navigationPath
            )
            
            // Content Processing Overlay
            if externalContentVM.isProcessingContent || externalContentVM.isWaitingForPlaceDetail || deepLinkViewModel.isProcessingDeepLink {
                externalContentOverlay
            }
        }
    }
    
    private var externalContentOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                if externalContentVM.importError != nil {
                    errorContent
                } else {
                    loadingContent
                }
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
    
    private var errorContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Import Failed")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(externalContentVM.importError ?? "")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("OK") {
                externalContentVM.clearImportError()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(8)
        }
    }
    
    private var loadingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Processing Video...")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Extracting location and saving place")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private func navigateToCreatePost() {
        photoImportVM.showPostCreation = false
        showCreatePost = true
    }
}

// MARK: - View Modifiers

struct ToolbarModifier: ViewModifier {
    @Binding var presentationMode: PresentationMode
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @ObservedObject var profile: ProfileViewModel
    @EnvironmentObject var serviceContainer: ServiceContainer

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarItems
                }
            }
    }

    // MARK: - Toolbar Components

    private var backButton: some View {
        Button(action: {
            presentationMode.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundColor(.black)
                Text("Back")
                    .foregroundColor(.black)
            }
        }
    }

    private var trailingToolbarItems: some View {
        HStack(spacing: 16) {
            // Share own profile button
            if let user = profile.user {
                ProfileShareButton(
                    userId: user.id,
                    fullName: user.fullName,
                    profilePhotoURL: user.profilePhotoURL?.absoluteString,
                    style: .toolbar
                )
            }

            Button {
                photoImportVM.handleImportButtonTap()
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.1))
                    .font(.body)
            }

            AccountMenuView()
        }
    }
}

struct SheetsModifier: ViewModifier {
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @ObservedObject var profile: ProfileViewModel
    @ObservedObject var placeVM: DetailPlaceViewModel
    @ObservedObject var externalContentVM: ProfileExternalContentViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Binding var showCreatePost: Bool
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var dataManager: DataManager
    @Binding var postWasSubmitted: Bool

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $photoImportVM.showPhotoPicker,
                selection: $photoImportVM.selectedItems,
                maxSelectionCount: 20,
                matching: .images,
                photoLibrary: .shared()
            )
            .alert("Import Photos", isPresented: $photoImportVM.showImportOnboarding) {
                Button("Got it") {
                    photoImportVM.confirmOnboarding()
                }
            } message: {
                Text("Select up to 20 photos from different places — we'll recognize each location and send you through a quick review for each one.")
            }
            .sheet(isPresented: $photoImportVM.showPlaceSelection) {
                PlaceSelectionView(
                    photoImportVM: photoImportVM,
                    profileVM: profile,
                    selectedPlaceVM: selectedPlaceVM,
                    detailPlaceVM: placeVM
                )
            }
            .sheet(isPresented: $photoImportVM.showClusterOverview) {
                PhotoClusterOverviewView(
                    clusteringVM: photoImportVM.clusteringVM,
                    photoImportVM: photoImportVM,
                    profileVM: profile
                )
                .environmentObject(selectedPlaceVM)
                .environmentObject(placeVM)
                .environmentObject(userSession)
            }
            .sheet(isPresented: Binding(
                get: { externalContentVM.isShowingPlaceSelection },
                set: { externalContentVM.isShowingPlaceSelection = $0 }
            )) {
                ExternalPlaceSelectionView()
                    .environmentObject(profile)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(placeVM)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: Binding(
                get: { externalContentVM.isShowingNoPlacesFound },
                set: { externalContentVM.isShowingNoPlacesFound = $0 }
            )) {
                NoPlacesFoundView(contentUrl: externalContentVM.noPlacesFoundContentUrl)
                    .environmentObject(profile)
                    .environmentObject(userSession)
                    .environmentObject(placeVM)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCreatePost) {
                createPostScreen
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
    
    private var createPostScreen: some View {
        Group {
            if let resolvedPlace = photoImportVM.resolvedPlace,
               !photoImportVM.selectedImages.isEmpty {
                CreatePostView(
                    place: resolvedPlace,
                    userId: userSession.currentUserId ?? "",
                    profilePhotoUrl: profile.user?.profilePhotoURL?.absoluteString ?? "",
                    userFirstName: profile.user?.firstName ?? "",
                    userLastName: profile.user?.lastName ?? "",
                    preselectedImages: photoImportVM.selectedImages,
                    onPostSubmitted: { place in
                        handlePostSubmission(place: place)
                    }
                )
                .environmentObject(selectedPlaceVM)
            } else if photoImportVM.isResolvingPlace {
                // Show loading while resolving place
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading place...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyView()
            }
        }
    }
    
    private func handlePostSubmission(place: DetailPlace) {
        postWasSubmitted = true

        // Use resolvedPlace which has the correct backend UUID
        guard let resolvedPlace = photoImportVM.resolvedPlace else {
            print("❌ No resolved place for navigation")
            return
        }

        Task {
            await photoImportVM.saveSelectedPlaceAfterReview()

            // End the photo import flow before navigating
            await MainActor.run {
                photoImportVM.isInPhotoImportFlow = false
                showCreatePost = false
            }

            // Allow time for the sheet to dismiss before navigating
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            await MainActor.run {
                selectedPlaceVM.allowAutoPresent = true
                photoImportVM.navigateToPlaceDetail(place: resolvedPlace)
            }
        }
    }
}

struct StateChangesModifier: ViewModifier {
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @ObservedObject var profile: ProfileViewModel
    @ObservedObject var placeVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var deepLinkViewModel: DeepLinkViewModel
    @Binding var showCreatePost: Bool
    @Binding var postWasSubmitted: Bool
    @ObservedObject var externalContentService: ExternalContentService
    @Binding var hasRefreshedPlaces: Bool  // Track if refresh already happened
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Places are already loaded in startup phase - no need to refresh again
                // This was causing 1.7s delay on profile view appearance
                // External places are loaded on-demand when user swipes to that tab
            }
            .onChange(of: photoImportVM.selectedItems) {
                Task {
                    await photoImportVM.processSelectedPhotos()
                }
            }
            .onAppear {
                setupCallbacks()
                profile.checkPendingContentURL(
                    externalContentService: externalContentService,
                    selectedPlaceVM: selectedPlaceVM,
                    placeVM: placeVM
                )
            }
            .onChange(of: showCreatePost) {
                handleCreatePostChange()
            }
            .onChange(of: photoImportVM.showPostCreation) {
                // Skip in multi-cluster mode — the overview handles its own flow
                if photoImportVM.showPostCreation && !photoImportVM.showClusterOverview {
                    photoImportVM.showPostCreation = false
                    showCreatePost = true
                }
            }
            .onChange(of: photoImportVM.shouldNavigateToPlaceDetail) {
                handlePlaceDetailNavigation()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProcessSharedContent"))) { notification in
                handleExternalContentNotification(notification)
            }
    }
    
    private func setupCallbacks() {
        photoImportVM.onPlaceSaved = {
            Task.detached(priority: .utility) {
                await profile.refreshUserPlaces()
            }
        }
        
        photoImportVM.onPlaceSavedWithDetail = { detailPlace in
            placeVM.places[detailPlace.id.uuidString] = detailPlace
            placeVM.placeSavers[detailPlace.id.uuidString] = [userSession.currentUserId ?? ""]
            placeVM.calculateAnnotationPlaces()
        }
    }
    
    private func handleCreatePostChange() {
        if !showCreatePost {
            if postWasSubmitted {
                postWasSubmitted = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    photoImportVM.clearSelection()
                }
            } else {
                photoImportVM.clearSelection()
            }
        }
    }
    
    private func handlePlaceDetailNavigation() {
        if photoImportVM.shouldNavigateToPlaceDetail,
           let place = photoImportVM.createdPlaceForDetail,
           !photoImportVM.isInPhotoImportFlow {
            
            // Animate map to newly created place location and fetch fresh details
            selectedPlaceVM.selectPlaceAndFetchDetails(place, shouldAnimateMap: true)
            selectedPlaceVM.isDetailSheetPresented = true
            
            photoImportVM.shouldNavigateToPlaceDetail = false
            photoImportVM.createdPlaceForDetail = nil
        }
    }
    
    private func handleExternalContentNotification(_ notification: Notification) {
        if let url = notification.userInfo?["url"] as? String {
            profile.handleContentNotification(
                url: url,
                externalContentService: externalContentService,
                selectedPlaceVM: selectedPlaceVM,
                placeVM: placeVM
            )
        }
    }
}

// MARK: - Account Management Modifier
/// Single Responsibility: Handles delete account two-step confirmation and loading state UI
struct AccountManagementModifier: ViewModifier {
    @ObservedObject var accountViewModel: ProfileAccountViewModel

    func body(content: Content) -> some View {
        content
            // Step 1: Initial Warning
            .alert("Delete Account?", isPresented: $accountViewModel.showDeleteAccountWarning) {
                Button("Cancel", role: .cancel) {
                    accountViewModel.cancelDeleteAccount()
                }
                Button("Continue", role: .destructive) {
                    accountViewModel.proceedToFinalConfirmation()
                }
            } message: {
                Text("This will permanently delete your account and all your data including:\n\n• All saved places\n• Your reviews and photos\n• Your lists\n• Followers and following\n\nThis action cannot be undone.")
            }
            // Step 2: Final Confirmation
            .alert("⚠️ Final Warning", isPresented: $accountViewModel.showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {
                    accountViewModel.cancelDeleteAccount()
                }
                Button("Delete Forever", role: .destructive) {
                    accountViewModel.initiateAccountDeletion()
                }
            } message: {
                Text("Are you absolutely sure? Your account and all data will be permanently deleted. This cannot be recovered.")
            }
            // Error Alert
            .alert("Error", isPresented: deleteAccountErrorBinding) {
                Button("OK") {
                    accountViewModel.clearDeleteAccountError()
                }
            } message: {
                if let error = accountViewModel.deleteAccountError {
                    Text(error)
                }
            }
            .overlay(deletingAccountOverlay)
    }

    // MARK: - Computed Properties

    private var deleteAccountErrorBinding: Binding<Bool> {
        Binding(
            get: { accountViewModel.deleteAccountError != nil },
            set: { if !$0 { accountViewModel.clearDeleteAccountError() } }
        )
    }

    // MARK: - Overlay Views

    @ViewBuilder
    private var deletingAccountOverlay: some View {
        if accountViewModel.isDeletingAccount {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Deleting Account...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("This may take a few moments")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(30)
                .background(Color.black.opacity(0.8))
                .cornerRadius(15)
            }
        }
    }
}