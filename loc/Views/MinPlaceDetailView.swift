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
            VStack(alignment: .leading, spacing: 10) {
                
                // Top row: Title + icons on the right
                HStack(alignment: .center) {
                    Text(place.name ?? "Unnamed Place")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.black)
                    
                    Spacer()
                    
                    Button(action: { /* your action */ }) {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                    .padding(.trailing, 8)
                    
                    Button(action: { /* your action */ }) {
                        Image(systemName: "bookmark")
                            .font(.title3)
                    }
                }
                
                // Sub‐title row: Type, status, drive time
                HStack(spacing: 8) {
                    Text(place.types?.first ?? "N/A")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                    Text("Open")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Image(systemName: "car.fill")
                        .foregroundColor(.gray)
                    Text("5 min")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Rating, “Reviews,” and avatars
                HStack(spacing: 8) {
                    Text("ABOUT")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)

                    Text(String(format: "%.1f", place.rating))
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.yellow)
                        .cornerRadius(4)
                    Text("REVIEWS")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
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
                        Text("+5")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.leading, 12)
                    }
                }
                
                Text(place.description ?? "No description available")
                    .font(.footnote)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .offset(y: -10) // Move content up slightly
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
