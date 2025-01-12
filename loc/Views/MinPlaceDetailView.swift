//
//  MinPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/9/25.
//

import SwiftUI
import GooglePlaces

struct MinPlaceDetailView: View {
    @ObservedObject var viewModel: PlaceDetailViewModel
    let place: GMSPlace
    
    @Binding var selectedImage: UIImage?

    
    // Tracks which tab is selected: ABOUT or REVIEWS
    @State private var selectedTab: DetailTab = .about
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                
                // MARK: - Top Row: Title + Icons
                HStack(alignment: .center) {
                    Text(place.name ?? "Unnamed Place")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            // your action for the “plus” button
                        }) {
                            Image(systemName: "plus")
                                .font(.title3)
                        }
                        
                        Button(action: {
                            // your action for the “bookmark” button
                        }) {
                            Image(systemName: "bookmark")
                                .font(.title3)
                        }
                    }
                }
                .padding(.bottom, 3)
                
                // MARK: - Row: Type / Status / Drive Time
                HStack(spacing: 10) {
                    Text(viewModel.getRestaurantType(for: place) ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                        
                        Text("Open")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .foregroundColor(.gray)
                        
                        Text("5 min")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 10)
                
                // MARK: - Row: ABOUT / Rating / REVIEWS / Avatars
                HStack(spacing: 12) {
                    
                    // ABOUT button (custom “underline”)
                    Button(action: {
                        selectedTab = .about
                    }) {
                        Text("ABOUT")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            // Add a bit of bottom padding so there’s room for the line
                            .padding(.bottom, 5)
                            // Overlay a Rectangle only if this tab is selected
                            .overlay(
                                Group {
                                    if selectedTab == .about {
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(height: 3)    // Thicker line
                                            .offset(y: 6)        // Move it farther below the text
                                    }
                                },
                                alignment: .bottom
                            )
                    }
                    
                    // Rating label (not a button)
                    Text(String(format: "%.1f", place.rating))
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .cornerRadius(10)
                    
                    // REVIEWS button (custom “underline”)
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
                    // “About” content
                    Text(place.editorialSummary ?? "No description available")
                        .font(.footnote)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                    
                    // Example: embedding MaxPlaceDetailView here
                    MaxPlaceDetailView(viewModel: viewModel, place: place,selectedImage: $selectedImage)
                    
                case .reviews:
                    // “Reviews” content
                    Text("Reviews content here...")
                        .font(.footnote)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // or a custom ReviewsView, e.g.:
                    // ReviewsView(viewModel: viewModel, place: place)
                }
            }
            .padding(.horizontal, 30)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sub-Types

enum DetailTab {
    case about
    case reviews
}
