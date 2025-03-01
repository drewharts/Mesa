//
//  MinPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/9/25.
//

import SwiftUI
import GooglePlaces

struct MinPlaceDetailView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @ObservedObject var viewModel: PlaceDetailViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager

    @Binding var showNoPhoneNumberAlert: Bool
    
    @Binding var selectedImage: UIImage?
    
    // Tracks which tab is selected: ABOUT or REVIEWS
    @State private var selectedTab: DetailTab = .about
    
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
                        NavigationLink(destination: PlaceReviewView(isPresented: .constant(false), place: selectedPlaceVM.selectedPlace!,userId: profile.userId,userFirstName: profile.data.firstName,userLastName: profile.data.lastName)) {
                            Image(systemName: "plus")
                                .font(.title3)
                        }
                        
                        Button(action: {
                            // 1) Present the ListSelectionSheet to add this place to a list
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
                    Text(viewModel.getRestaurantType(for:selectedPlaceVM.selectedPlace!) ?? "Restuarant")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(viewModel.isOpen ? .green : .red)
                        
                        Text(viewModel.isOpen ? "Open" : "Closed")
                            .font(.subheadline)
                            .foregroundColor(viewModel.isOpen ? .green : .red)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .foregroundColor(.gray)
                        
                        Text(viewModel.travelTime)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .onTapGesture {
                        // Ensure you have a selected place and a valid current location.
                        if let place = selectedPlaceVM.selectedPlace,
                           let currentLocation = locationManager.currentLocation {
                            viewModel.openNavigation(for: place, currentLocation: currentLocation.coordinate)
                        }
                    }
                }
                .padding(.bottom, 10)
                
                // MARK: - Row: ABOUT / Rating / REVIEWS / Avatars
                HStack(spacing: 12) {
                    
                    // ABOUT button
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
                    
                    // Updated Rating label (adapted for Mapsbox)
                    Text(String(format: "%.1f", selectedPlaceVM.selectedPlace?.rating ?? 0.0))
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .cornerRadius(10)
                    
                    // REVIEWS button
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
                    
                    // Example avatar stack
                    HStack(spacing: -10) {
                        ForEach(0..<3) { _ in
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
                    // "About" content
                    Text(selectedPlaceVM.selectedPlace?.description ?? "No description available")
                        .font(.footnote)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                    
                    // Example: embedding MaxPlaceDetailView
                    //TODO: the viewmodel has no images when clicked to from the profile favs
                    MaxPlaceDetailView(
                        viewModel: viewModel,
                        selectedImage: $selectedImage,
                        showNoPhoneNumberAlert: $showNoPhoneNumberAlert
                    )
                    
                case .reviews:
                    // "Reviews" content
                    PlaceReviewsView(reviews: selectedPlaceVM.reviews)
                }
            }
            .padding(.horizontal, 30)
        }
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
