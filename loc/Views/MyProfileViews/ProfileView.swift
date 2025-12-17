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
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var deepLinkViewModel: DeepLinkViewModel
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var photoImportVM = PhotoImportViewModel()
    @StateObject private var tikTokService = TikTokService()
    
    @State private var showCreatePost = false
    @State private var postWasSubmitted = false
    
    // Track if we've already done initial data refresh
    @State private var hasRefreshedPlaces = false

    init() {
        // Configure navigation bar appearance to remove the bottom border
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground() // Use opaque background
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarBackButtonHidden(true)
                .preferredColorScheme(.light)
                .navigationBarTitleDisplayMode(.inline)
                .modifier(ToolbarModifier(
                    presentationMode: presentationMode,
                    photoImportVM: photoImportVM
                ))
                .navigationDestination(isPresented: $userProfileViewModel.isUserDetailPresented) {
                    UserProfileView(
                        userId: userSession.currentUserId ?? "",
                        UserProfileVM: userProfileViewModel
                    )
                    .environmentObject(profile)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(placeVM)
                }
        }
            .modifier(SheetsModifier(
                photoImportVM: photoImportVM,
                profile: profile,
                placeVM: placeVM,
                showCreatePost: $showCreatePost,
                postWasSubmitted: $postWasSubmitted
            ))
            .modifier(StateChangesModifier(
                photoImportVM: photoImportVM,
                profile: profile,
                placeVM: placeVM,
                showCreatePost: $showCreatePost,
                postWasSubmitted: $postWasSubmitted,
                tikTokService: tikTokService,
                hasRefreshedPlaces: $hasRefreshedPlaces
            ))
            .alert("No Location Found", isPresented: $deepLinkViewModel.showNoLocationAlert) {
                Button("OK") {
                    deepLinkViewModel.dismissNoLocationAlert()
                }
            } message: {
                Text(deepLinkViewModel.noLocationAlertMessage)
            }
            .sheet(isPresented: $profile.isShowingNoPlacesFound) {
                TikTokNoPlacesFoundView(tikTokUrl: profile.noPlacesFoundTikTokUrl)
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
            .modifier(AccountManagementModifier(profile: profile))
    }
    
    private var mainContent: some View {
        ZStack {
            // Main Content
            ProfileContentView(photoImportVM: photoImportVM)
            
            // TikTok Processing Overlay
            if profile.isProcessingTikTok || profile.isWaitingForPlaceDetail || deepLinkViewModel.isProcessingDeepLink {
                tikTokOverlay
            }
        }
    }
    
    private var tikTokOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                if profile.tikTokImportError != nil {
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
            
            Text(profile.tikTokImportError ?? "")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("OK") {
                profile.clearTikTokImportError()
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
            
            Text("Processing TikTok Video...")
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
            PhotosPicker(
                selection: $photoImportVM.selectedItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "photo.badge.plus")
                    .foregroundColor(.black)
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
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Binding var showCreatePost: Bool
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var dataManager: DataManager
    @Binding var postWasSubmitted: Bool
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $photoImportVM.showPlaceSelection) {
                PlaceSelectionView(photoImportVM: photoImportVM)
            }
            .sheet(isPresented: $profile.isShowingPlaceSelection) {
                TikTokPlaceSelectionView()
                    .environmentObject(profile)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(placeVM)
                    .environmentObject(dataManager)
                    .environmentObject(userSession)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $profile.isShowingNoPlacesFound) {
                TikTokNoPlacesFoundView(tikTokUrl: profile.noPlacesFoundTikTokUrl)
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
            if let selectedPlace = photoImportVM.selectedPlace,
               !photoImportVM.selectedImages.isEmpty {
                CreatePostView(
                    place: profile.convertToDetailPlace(selectedPlace),
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
            } else {
                EmptyView()
            }
        }
    }
    
    private func handlePostSubmission(place: DetailPlace) {
        postWasSubmitted = true
        
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
                photoImportVM.navigateToPlaceDetail(place: place)
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
    @ObservedObject var tikTokService: TikTokService
    @Binding var hasRefreshedPlaces: Bool  // Track if refresh already happened
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Places are already loaded in startup phase - no need to refresh again
                // This was causing 1.7s delay on profile view appearance
                // External places (TikTok) are loaded on-demand when user swipes to that tab
            }
            .onChange(of: photoImportVM.selectedItems) {
                Task {
                    await photoImportVM.processSelectedPhotos()
                }
            }
            .onAppear {
                setupCallbacks()
                profile.checkPendingTikTokURL(
                    tikTokService: tikTokService,
                    selectedPlaceVM: selectedPlaceVM,
                    placeVM: placeVM
                )
            }
            .onChange(of: showCreatePost) {
                handleCreatePostChange()
            }
            .onChange(of: photoImportVM.showPostCreation) {
                if photoImportVM.showPostCreation {
                    photoImportVM.showPostCreation = false
                    showCreatePost = true
                }
            }
            .onChange(of: photoImportVM.shouldNavigateToPlaceDetail) {
                handlePlaceDetailNavigation()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProcessSharedTikTok"))) { notification in
                handleTikTokNotification(notification)
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
    
    private func handleTikTokNotification(_ notification: Notification) {
        if let url = notification.userInfo?["url"] as? String {
            profile.handleTikTokNotification(
                url: url,
                tikTokService: tikTokService,
                selectedPlaceVM: selectedPlaceVM,
                placeVM: placeVM
            )
        }
    }
}

// MARK: - Account Management Modifier
/// Single Responsibility: Handles delete account two-step confirmation and loading state UI
struct AccountManagementModifier: ViewModifier {
    @ObservedObject var profile: ProfileViewModel
    
    func body(content: Content) -> some View {
        content
            // Step 1: Initial Warning
            .alert("Delete Account?", isPresented: $profile.showDeleteAccountWarning) {
                Button("Cancel", role: .cancel) {
                    profile.cancelDeleteAccount()
                }
                Button("Continue", role: .destructive) {
                    profile.proceedToFinalConfirmation()
                }
            } message: {
                Text("This will permanently delete your account and all your data including:\n\n• All saved places\n• Your reviews and photos\n• Your lists\n• Followers and following\n\nThis action cannot be undone.")
            }
            // Step 2: Final Confirmation
            .alert("⚠️ Final Warning", isPresented: $profile.showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) {
                    profile.cancelDeleteAccount()
                }
                Button("Delete Forever", role: .destructive) {
                    profile.initiateAccountDeletion()
                }
            } message: {
                Text("Are you absolutely sure? Your account and all data will be permanently deleted. This cannot be recovered.")
            }
            // Error Alert
            .alert("Error", isPresented: deleteAccountErrorBinding) {
                Button("OK") {
                    profile.clearDeleteAccountError()
                }
            } message: {
                if let error = profile.deleteAccountError {
                    Text(error)
                }
            }
            .overlay(deletingAccountOverlay)
    }
    
    // MARK: - Computed Properties
    
    private var deleteAccountErrorBinding: Binding<Bool> {
        Binding(
            get: { profile.deleteAccountError != nil },
            set: { if !$0 { profile.clearDeleteAccountError() } }
        )
    }
    
    // MARK: - Overlay Views
    
    @ViewBuilder
    private var deletingAccountOverlay: some View {
        if profile.isDeletingAccount {
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