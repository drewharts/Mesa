//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var placeVM: DetailPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var deepLinkViewModel: DeepLinkViewModel
    @StateObject private var photoImportVM = PhotoImportViewModel()
    
    @State private var showCreateReview = false
    @State private var selectedReviewType: CreatePlaceReviewView.ReviewType = .restaurant
    @State private var reviewWasSubmitted = false
    @StateObject private var tikTokService = TikTokService()

    init() {
        // Configure navigation bar appearance to remove the bottom border
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground() // Use opaque background
    }

    var body: some View {
        mainContent
            .navigationBarBackButtonHidden(true)
            .preferredColorScheme(.light)
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ToolbarModifier(
                presentationMode: presentationMode,
                photoImportVM: photoImportVM
            ))
            .modifier(SheetsModifier(
                photoImportVM: photoImportVM,
                profile: profile,
                placeVM: placeVM,
                showCreateReview: $showCreateReview,
                selectedReviewType: selectedReviewType,
                reviewWasSubmitted: $reviewWasSubmitted,
                onGenericReview: navigateToGenericReview,
                onRestaurantReview: navigateToRestaurantReview
            ))
            .modifier(StateChangesModifier(
                photoImportVM: photoImportVM,
                profile: profile,
                placeVM: placeVM,
                showCreateReview: $showCreateReview,
                reviewWasSubmitted: $reviewWasSubmitted,
                tikTokService: tikTokService
            ))
            .alert("No Location Found", isPresented: $deepLinkViewModel.showNoLocationAlert) {
                Button("OK") {
                    deepLinkViewModel.dismissNoLocationAlert()
                }
            } message: {
                Text(deepLinkViewModel.noLocationAlertMessage)
            }
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
    
    private func navigateToRestaurantReview() {
        selectedReviewType = .restaurant
        photoImportVM.showReviewTypeSelection = false
        showCreateReview = true
    }
    
    private func navigateToGenericReview() {
        selectedReviewType = .generic
        photoImportVM.showReviewTypeSelection = false
        showCreateReview = true
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
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    .padding(.trailing, 10)
                }
            }
    }
}

struct SheetsModifier: ViewModifier {
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @ObservedObject var profile: ProfileViewModel
    @ObservedObject var placeVM: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Binding var showCreateReview: Bool
    let selectedReviewType: CreatePlaceReviewView.ReviewType
    @EnvironmentObject var userSession: UserSession
    @Binding var reviewWasSubmitted: Bool
    let onGenericReview: () -> Void
    let onRestaurantReview: () -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $photoImportVM.showPlaceSelection) {
                PlaceSelectionView(photoImportVM: photoImportVM)
            }
            .sheet(isPresented: $photoImportVM.showReviewTypeSelection) {
                ReviewTypeSelectionView(
                    photoImportVM: photoImportVM,
                    onGenericReview: onGenericReview,
                    onRestaurantReview: onRestaurantReview
                )
            }
            .sheet(isPresented: $profile.isShowingPlaceSelection) {
                TikTokPlaceSelectionView()
                    .environmentObject(profile)
                    .environmentObject(selectedPlaceVM)
                    .environmentObject(placeVM)
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showCreateReview) {
                reviewScreen
            }
    }
    
    private var reviewScreen: some View {
        Group {
            if let selectedPlace = photoImportVM.selectedPlace,
               !photoImportVM.selectedImages.isEmpty {
                CreatePlaceReviewView(
                    isPresented: $showCreateReview,
                    place: profile.convertToDetailPlace(selectedPlace),
                    userId: userSession.currentUserId ?? "",
                    profilePhotoUrl: profile.user?.profilePhotoURL?.absoluteString ?? "",
                    userFirstName: profile.user?.firstName ?? "",
                    userLastName: profile.user?.lastName ?? "",
                    preselectedImages: photoImportVM.selectedImages,
                    reviewType: selectedReviewType,
                    onReviewSubmitted: { place in
                        handleReviewSubmission(place: place)
                    }
                )
            } else {
                EmptyView()
            }
        }
    }
    
    private func handleReviewSubmission(place: DetailPlace) {
        reviewWasSubmitted = true
        
        Task {
            await photoImportVM.saveSelectedPlaceAfterReview()
            
            // End the photo import flow before navigating
            await MainActor.run {
                photoImportVM.isInPhotoImportFlow = false
                showCreateReview = false
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
    @Binding var showCreateReview: Bool
    @Binding var reviewWasSubmitted: Bool
    @ObservedObject var tikTokService: TikTokService
    
    func body(content: Content) -> some View {
        content
            .task {
                await profile.refreshUserPlaces()
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
            .onChange(of: showCreateReview) {
                handleCreateReviewChange()
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
            Task {
                await profile.refreshUserPlaces()
            }
        }
        
        photoImportVM.onPlaceSavedWithDetail = { detailPlace in
            placeVM.places[detailPlace.id.uuidString] = detailPlace
            placeVM.placeSavers[detailPlace.id.uuidString] = [userSession.currentUserId ?? ""]
            placeVM.calculateAnnotationPlaces()
        }
    }
    
    private func handleCreateReviewChange() {
        if !showCreateReview {
            if reviewWasSubmitted {
                reviewWasSubmitted = false
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
            
            selectedPlaceVM.selectedPlace = place
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