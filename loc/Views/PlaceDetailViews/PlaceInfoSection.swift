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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Rating Row (Google/Mapbox)
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
                .padding(.bottom, 8)
            }
            
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
    
    return PlaceInfoSection(place: mockPlace)
        .padding()
}

