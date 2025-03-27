//
//  MinPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/9/25.
//

import SwiftUI
import FirebaseFirestore

struct MinPlaceDetailView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @ObservedObject var viewModel: PlaceDetailViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.isScrollingEnabled) var isScrollingEnabled // Access scroll state

    @Binding var showNoPhoneNumberAlert: Bool
    @Binding var selectedImage: UIImage?
    
    @State private var selectedTab: DetailTab = .reviews
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                // MARK: - Top Row: Title + Icons
                HStack(alignment: .center) {
                    Text(selectedPlaceVM.selectedPlace?.name ?? "Unnamed Place")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        NavigationLink(destination: PlaceReviewView(isPresented: .constant(false), place: selectedPlaceVM.selectedPlace!, userId: profile.userId, profilePhotoUrl: profile.data.profilePhotoURL?.absoluteString ?? "", userFirstName: profile.data.firstName, userLastName: profile.data.lastName)) {
                            Image(systemName: "plus")
                                .font(.title3)
                        }
                        
                        Button(action: {
                            viewModel.showListSelection = true
                        }) {
                            Image(systemName: "bookmark")
                                .font(.title3)
                        }
                    }
                }
                .padding(.bottom, 3)
                
                // MARK: - Row: Type / Status / Drive Time
                HStack(spacing: 10) {
                    Text(viewModel.getRestaurantType(for: selectedPlaceVM.selectedPlace!) ?? "Restaurant")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(selectedPlaceVM.isRestaurantOpen ? .green : .red)
                        
                        Text(selectedPlaceVM.isRestaurantOpen ? "Open" : "Closed")
                            .font(.subheadline)
                            .foregroundColor(selectedPlaceVM.isRestaurantOpen ? .green : .red)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .foregroundColor(.gray)
                        
                        Text(viewModel.travelTime)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .onTapGesture {
                        if let place = selectedPlaceVM.selectedPlace,
                           let currentLocation = locationManager.currentLocation {
                            viewModel.openNavigation(for: place, currentLocation: currentLocation.coordinate)
                        }
                    }
                }
                .padding(.bottom, 10)
                
                // MARK: - Row: REVIEWS / Rating / ABOUT / Avatars
                HStack(spacing: 12) {
                    Button(action: {
                        selectedTab = .reviews
                    }) {
                        Text("REVIEWS")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if selectedTab == .reviews {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                            .offset(y: 6)
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    
                    Text(String(format: "%.1f", selectedPlaceVM.placeRating ?? 0.0))
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .cornerRadius(10)
                    
                    Button(action: {
                        selectedTab = .about
                    }) {
                        Text("ABOUT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.bottom, 5)
                            .overlay(
                                Group {
                                    if selectedTab == .about {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)
                                            .offset(y: 6)
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    

                    
                    HStack(spacing: -10) {
                        ForEach(0..<2) { _ in
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: 2)
                                )
                        }
                        
                        ZStack {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: 2)
                                )
                            
                            Text("+5")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 10)
                
                // MARK: - Tab-Specific Content
                switch selectedTab {
                case .about:
                    Text(selectedPlaceVM.selectedPlace?.description ?? "No description available")
                        .font(.footnote)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                    
                    MaxPlaceDetailView(
                        viewModel: viewModel,
                        selectedImage: $selectedImage,
                        showNoPhoneNumberAlert: $showNoPhoneNumberAlert
                    )
                case .reviews:
                    PlaceReviewsView(selectedImage: $selectedImage)
                    
                }
            }
            .padding(.horizontal, 30)
        }
        .scrollDisabled(!isScrollingEnabled) // Disable scrolling based on sheet height
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showNoPhoneNumberAlert) {
            Alert(
                title: Text("Phone Number Not Available"),
                message: Text("No phone number is available for this place."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// MARK: - Sub-Types
enum DetailTab {
    case about
    case reviews
}

// MARK: - Preview Provider
// MARK: - Preview Provider
//struct MinPlaceDetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        // Create mock instances for dependencies
//        let mockLocationManager = LocationManager()
//        let mockFirestoreService = FirestoreService()
//        let mockProfileData = ProfileData(
//            id: "", firstName: "drew", lastName: "hartsfield", email: "drew", profilePhotoURL: URL(string: ""), phoneNumber: "801"
//        )
//        let mockUserId = "user123"
//        
//        // Create mock ProfileViewModel with required parameters
//        let mockProfile = ProfileViewModel(
//            data: mockProfileData,
//            firestoreService: mockFirestoreService,
//            userId: mockUserId
//        )
//        
//        let mockPlaceDetailVM = PlaceDetailViewModel()
//        let mockSelectedPlaceVM = SelectedPlaceViewModel(
//            locationManager: mockLocationManager,
//            firestoreService: mockFirestoreService
//        )
//        
//        // Set up mock data for selectedPlaceVM
//        mockSelectedPlaceVM.selectedPlace = DetailPlace()
//        
//        // Set up mock data for profile (already set in mockProfileData)
//        
//        // Set up mock reviews for selectedPlaceVM (optional, for the Reviews tab)
//        mockSelectedPlaceVM.reviews = [
//            Review(
//                id: "review1",
//                userId: "user123",
//                profilePhotoUrl: "",
//                userFirstName: "Mada",
//                userLastName: "Graviet",
//                placeId: "place123",
//                placeName: "Sample Restaurant",
//                foodRating: 7.8,
//                serviceRating: 4.3,
//                ambienceRating: 8.1,
//                favoriteDishes: ["roasted chicken", "grilled salmon"],
//                reviewText: "\"This is definitely a new favorite. Service was really slow but food made up for it.\"",
//                timestamp: Date().addingTimeInterval(-172800), // 2 days ago
//                images: ["https://example.com/restaurant.jpg", "https://example.com/food.jpg"]
//            )
//        ]
//        
//        // Configure PlaceDetailViewModel with mock data
//        mockPlaceDetailVM.isOpen = true
//        mockPlaceDetailVM.travelTime = "15 min"
//        
//        return MinPlaceDetailView(
//            viewModel: mockPlaceDetailVM,
//            showNoPhoneNumberAlert: .constant(false),
//            selectedImage: .constant(nil)
//        )
//        .environmentObject(mockProfile)
//        .environmentObject(mockSelectedPlaceVM)
//        .environmentObject(mockLocationManager)
//    }
//}
