//  PlaceSelectionRowView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI

struct PlaceSelectionRowView: View {
    let place: NearbyPlaceFeature
    let onSelect: () -> Void
    let isLoading: Bool
    
    init(place: NearbyPlaceFeature, onSelect: @escaping () -> Void, isLoading: Bool = false) {
        self.place = place
        self.onSelect = onSelect
        self.isLoading = isLoading
    }
    
    private func formatDistance(meters: Double) -> String {
        let miles = meters * 0.000621371
        
        if miles < 0.1 {
            // For very short distances, show in feet
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        } else if miles < 1.0 {
            // For distances less than 1 mile, show with 2 decimal places
            return String(format: "%.2f mi", miles)
        } else {
            // For distances 1 mile or more, show with 1 decimal place
            return String(format: "%.1f mi", miles)
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Place Icon
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                
                // Place Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.properties.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                    
                    // Show description for Firestore places, address for Google Places
                    if let description = place.properties.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.purple)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(place.properties.address.isEmpty ? "Address not available" : place.properties.address)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                    
                    HStack {
                        // Distance
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                            Text(formatDistance(meters: place.properties.distanceMeters ?? 0))
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        // Rating if available
                        if let rating = place.properties.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                Text(String(format: "%.1f", rating))
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Selection Arrow or Loading Indicator
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
} 