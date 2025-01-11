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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                
                // Top row: Title + icons
                HStack(alignment: .center) {
                    Text(place.name ?? "Unnamed Place")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { /* your action */ }) {
                            Image(systemName: "plus")
                                .font(.title3)
                        }
                        
                        Button(action: { /* your action */ }) {
                            Image(systemName: "bookmark")
                                .font(.title3)
                        }
                    }
                }
                .padding(.bottom, 3)
                
                // Row: type / status / drive time
                HStack(spacing: 10) {
                    Text(viewModel.getRestaurantType(for: place) ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack(spacing:4) {
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
                
                // Row: ABOUT / rating / REVIEWS / avatars
                HStack(spacing: 12) {
                    Text("ABOUT")
                        .font(.subheadline)
                        .foregroundColor(.black)
                        .fontWeight(.semibold)
                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", place.rating))
                            .font(.caption)
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.yellow)
                            .cornerRadius(10)
                            
                        
                        Text("REVIEWS")
                            .font(.subheadline)
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                    }
                    
                    // Example avatar stack
                    HStack(spacing: -10) {
                        // The first 3 “avatar” circles
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: 2)
                                )
                        }
                        
                        // The “+5” circle
                        ZStack {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(Color.white, lineWidth: 2)
                                )
                            
                            Text("+5")
                                .font(.caption)        // adjust font size as needed
                                .foregroundColor(.white)
                        }
                    }

                }
                .padding(.bottom, 10)
                
                // Description
                Text(place.editorialSummary ?? "No description available")
                    .font(.footnote)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                    .padding(.top, 15)
                    .padding(.bottom, 15)
                MaxPlaceDetailView(viewModel: viewModel)
                //make the rest of the view
            }
            // Add horizontal padding here so it’s not flush with the screen edges
            .padding(.horizontal, 30)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
