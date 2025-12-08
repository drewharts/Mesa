//
//  SaverRowView.swift
//  loc
//
//  DUMB Component - Pure display, no ViewModel, no state
//  Just displays user data and triggers callback on tap
//

import SwiftUI

struct SaverRowView: View {
    // MARK: - Parameters Only (No ViewModel!)
    let user: ProfileData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile image - uses AsyncImage with URL from ProfileData
                profileImageView
                
                // Name
                Text(user.fullName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Private Views
    
    @ViewBuilder
    private var profileImageView: some View {
        if let photoURL = user.profilePhotoURL {
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure, .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
            .frame(width: 50, height: 50)
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: 50, height: 50)
            .overlay(
                Text(user.fullName.prefix(1))
                    .font(.headline)
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - Preview (Super Simple for Dumb Component!)

#Preview {
    let mockUser = ProfileData(
        id: "123",
        firstName: "John",
        lastName: "Doe",
        email: "john@example.com",
        profilePhotoURL: nil,
        phoneNumber: "",
        fullNameLower: "john doe",
        fullName: "John Doe",
        fcmToken: nil,
        firebaseUid: nil,
        supabaseUid: nil
    )
    
    return SaverRowView(
        user: mockUser,
        onTap: { print("Tapped!") }
    )
    .padding()
}

