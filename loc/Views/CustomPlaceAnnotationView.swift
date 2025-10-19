//
//  CustomPlaceAnnotationView.swift
//  loc
//
//  Custom map annotation showing user profile photos
//

import SwiftUI

struct CustomPlaceAnnotationView: View {
    let annotation: PlaceAnnotation
    let userPhotos: [FollowedUserPhoto]
    
    // Get photos for users who saved this place
    private var relevantPhotos: [String] {
        return annotation.userIds.compactMap { userId in
            userPhotos.first(where: { $0.userId == userId })?.profilePhotoUrl
        }.prefix(3).map { $0 } // Show max 3 photos
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Profile photos stack
            if !relevantPhotos.isEmpty {
                HStack(spacing: -8) {
                    ForEach(Array(relevantPhotos.enumerated()), id: \.offset) { index, photoUrl in
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .zIndex(Double(relevantPhotos.count - index))
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
            } else {
                // Fallback to pin icon if no photos
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundColor(.red)
            }
            
            // Place name label
            Text(annotation.name)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                )
                .lineLimit(1)
        }
    }
}

