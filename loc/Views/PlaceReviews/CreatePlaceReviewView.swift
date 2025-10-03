//
//  PlaceReviewView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/13/25.
//

import SwiftUI
import PhotosUI
import MapboxSearch

struct CreatePlaceReviewView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlace: SelectedPlaceViewModel
    @State private var showButtonHighlight = false
    @State private var showAlert = false
    @State private var showSuccessAlert = false
    @State private var alertMessage = ""
    @State private var reviewType = ReviewType.restaurant
    
    let place: DetailPlace

    @StateObject private var viewModel: PlaceReviewViewModel
    
    // Image picker states
    @State private var showingImagePicker = false
    @State private var inputImages: [UIImage] = []
    
    // Add enum for review types
    enum ReviewType: String, CaseIterable {
        case restaurant = "Restaurant"
        case generic = "Generic"
    }
    
    let onReviewSubmitted: ((DetailPlace) -> Void)?
    
    init(isPresented: Binding<Bool>, place: DetailPlace, userId: String, profilePhotoUrl: String, userFirstName: String, userLastName: String, preselectedImages: [UIImage] = [], reviewType: ReviewType = .restaurant, onReviewSubmitted: ((DetailPlace) -> Void)? = nil) {
        self._isPresented = isPresented
        self.place = place
        self._reviewType = State(initialValue: reviewType)
        self.onReviewSubmitted = onReviewSubmitted

        // Initialize the ViewModel with place/user info
        _viewModel = StateObject(
            wrappedValue: PlaceReviewViewModel(
                place: place,
                userId: userId,
                userFirstName: userFirstName,
                userLastName: userLastName,
                profilePhotoUrl: profilePhotoUrl
            )
        )
        
        // Set preselected images if provided
        self._inputImages = State(initialValue: preselectedImages)
    }
    
    var btnBack : some View { Button(action: {
        // Don't allow dismissal while submitting
        guard !viewModel.isLoading else { return }
        
        // Close the review screen
        isPresented = false
        }) {
            HStack {
            Image(systemName: "chevron.left") // set image here
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.black)
            }
        }
        .disabled(viewModel.isLoading)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PlaceReviewHeaderView(placeName: place.name)
                    
                    // Add review type picker
                    Picker("Review Type", selection: $reviewType) {
                        ForEach(ReviewType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Show different rating options based on review type
                    if reviewType == .restaurant {
                        RatingSlidersView(foodRating: $viewModel.foodRating, serviceRating: $viewModel.serviceRating, ambienceRating: $viewModel.ambienceRating)
                        UpvoteFavDishesView(favoriteDishes: $viewModel.favoriteDishes)
                    }
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -10)

                    ReviewTextView(reviewText: $viewModel.reviewText)
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -10)

                    // Upload photos button
                    UploadPhotosButtonView(showingImagePicker: $showingImagePicker)
                    
                    // Display selected images
                    if !inputImages.isEmpty {
                        SelectedImagesView(images: $inputImages)
                    }
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -10)

                    PostReviewButtonView(highlighted: $showButtonHighlight, isLoading: $viewModel.isLoading) {
                        // 1. Immediately highlight the button
                        showButtonHighlight = true
                        
                        // 2. Pass the selected images to the ViewModel
                        viewModel.images = []
                        viewModel.images = inputImages
                        
                        // 3. Set the review type
                        viewModel.reviewType = reviewType
                        
                        // 4. Submit the review
                        viewModel.submitReview { result in
                            switch result {
                            case .success(let savedReview):
                                // Append the saved review to selectedPlace.reviews
                                selectedPlace.addReview(savedReview)
                                
                                // Wait briefly so user sees the highlight
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showButtonHighlight = false
                                    
                                    // Show success alert
                                    showSuccessAlert = true
                                }
                                
                            case .failure(let error):
                                // On failure, remove highlight
                                showButtonHighlight = false
                                
                                // Show alert with error message
                                alertMessage = error.localizedDescription
                                showAlert = true
                                
                                print("Review submission failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("Review Submission Failed"),
                            message: Text(alertMessage),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                    .alert("Review Posted!", isPresented: $showSuccessAlert) {
                        Button("OK") {
                            // Dismiss the review screen and call the callback
                            isPresented = false
                            onReviewSubmitted?(place)
                        }
                    } message: {
                        Text("Your review has been successfully posted!")
                    }
                }
                .padding(.horizontal, 40)
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
            .background(Color(.white))
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
        .sheet(isPresented: $showingImagePicker) {
            MultiImagePicker(images: $inputImages, selectionLimit: 0)
        }

    }
}
