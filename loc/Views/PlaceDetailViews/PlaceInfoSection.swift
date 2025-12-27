//
//  PlaceInfoSection.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Pure display component - no business logic, no ViewModel needed
//

import SwiftUI

struct PlaceInfoSection: View {
    let place: DetailPlace
    let totalSaveCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Stats Row: Rating + Save Count
            HStack(spacing: 16) {
                // External Rating (Google/Mapbox)
                if let rating = place.rating, rating > 0 {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            
                            if let count = place.userRatingsTotal, count > 0 {
                                Text("(\(count.formatted()) reviews)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Google logo
                        Image("GoogleLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 16)
                    }
                }
                
                // Divider if we have both rating and saves
                if place.rating != nil && place.rating! > 0 && totalSaveCount > 0 {
                    Text("·")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Save Count
                if totalSaveCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text("\(totalSaveCount) save\(totalSaveCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.bottom, 8)
            
            Text(place.description ?? "No description available")
                .font(.footnote)
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Preview (Super Simple!)
#Preview {
    var mockPlace = DetailPlace()
    mockPlace.name = "Sample Restaurant"
    mockPlace.description = "A cozy Italian restaurant serving authentic pasta and pizza in a warm, family-friendly atmosphere."
    mockPlace.rating = 4.5
    mockPlace.userRatingsTotal = 234
    
    return PlaceInfoSection(place: mockPlace, totalSaveCount: 42)
        .padding()
}

