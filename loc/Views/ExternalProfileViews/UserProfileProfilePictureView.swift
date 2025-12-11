//
//  UserProfileProfilePictureView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileProfilePictureView: View {
    let profilePhotoURL: URL?
    let isFollowing: Bool
    let onToggleFollow: () -> Void
    let totalPlacesCount: Int
    let userName: String
    
    // MARK: - Constants
    private let profileSize: CGFloat = 120
    
    @State private var showingPlacesCount = false
    
    // MARK: - Subtle Places Count Badge (matches own profile style)
    private var placesCountBadge: some View {
        let displayText = totalPlacesCount >= 1000 ? "\(totalPlacesCount / 1000)k+" : "\(totalPlacesCount)"
        
        return Button(action: {
            showingPlacesCount = true
        }) {
            Text(displayText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(minWidth: 24)  // Ensures badge extends past circle edge for single digits
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: 0)  // Pull badge onto the circle for visible overlap
    }

    var body: some View {
        VStack(spacing: 16) {
            // Profile image with places count badge
            ZStack(alignment: .bottomTrailing) {
                profileImageView
                    .frame(width: profileSize, height: profileSize)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                
                // Places count badge - subtle style matching own profile
                if totalPlacesCount > 0 {
                    placesCountBadge
                }
            }
            
            Button(action: onToggleFollow) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isFollowing ? .primary : .white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isFollowing ? Color(.systemGray5) : Color.blue)
                    )
            }
        }
        .padding(.top, 40)
        .alert("Places Saved", isPresented: $showingPlacesCount) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(userName) has \(totalPlacesCount) places saved across all their lists, favorites, and reviews.")
        }
    }
    
    // MARK: - Subviews
    
    private var profileImageView: some View {
        Group {
            if let profilePhotoURL = profilePhotoURL {
                AsyncImage(url: profilePhotoURL) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
    }
}
