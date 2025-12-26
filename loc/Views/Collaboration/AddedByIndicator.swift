//
//  AddedByIndicator.swift
//  loc
//
//  DUMB Component: Displays who added a place to a collaborative list
//  Single Responsibility: Show a compact "Added by [name]" indicator with avatar
//
//  Usage: Used in place grid cells ONLY for collaborative lists
//  For personal lists (single user), this indicator should not be shown
//

import SwiftUI

/// Compact indicator showing who added a place to a collaborative list
/// Pure display component - no business logic, no state management
struct AddedByIndicator: View {
    // MARK: - Pure Data Parameters (No ViewModel!)
    
    let name: String
    let photoUrl: String?
    
    // MARK: - Layout Constants
    
    private let avatarSize: CGFloat = 14
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            avatarView
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var avatarView: some View {
        if let photoUrl = photoUrl, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                case .failure, .empty:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
            .frame(width: avatarSize, height: avatarSize)
        } else {
            placeholderAvatar
        }
    }
    
    private var placeholderAvatar: some View {
        Circle()
            .fill(Color.white.opacity(0.3))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 20) {
            AddedByIndicator(
                name: "John Doe",
                photoUrl: "https://example.com/photo.jpg"
            )
            
            AddedByIndicator(
                name: "Jane Smith",
                photoUrl: nil
            )
        }
    }
}

