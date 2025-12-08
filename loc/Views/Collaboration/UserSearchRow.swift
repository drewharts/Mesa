//
//  UserSearchRow.swift
//  loc
//
//  DUMB Component: Displays a user in search results for adding as collaborator
//  Single Responsibility: Visual display of user search result
//

import SwiftUI

struct UserSearchRow: View {
    let user: ProfileData
    let selectedRole: CollaboratorRole
    let isAdding: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            profileImage
            userInfo
            Spacer()
            addButton
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Profile Image
    
    private var profileImage: some View {
        AsyncImage(url: user.profilePhotoURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure, .empty:
                placeholderImage
            @unknown default:
                placeholderImage
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }
    
    private var placeholderImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Text(user.fullName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(.gray)
            )
    }
    
    // MARK: - User Info
    
    private var userInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(user.fullName)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            if !user.email.isEmpty {
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Add Button
    
    private var addButton: some View {
        Button(action: onAdd) {
            if isAdding {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 70, height: 32)
            } else {
                Text("Add")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 70, height: 32)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .disabled(isAdding)
    }
}

// MARK: - Preview

#Preview {
    List {
        UserSearchRow(
            user: ProfileData(
                id: "1",
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
            ),
            selectedRole: .editor,
            isAdding: false,
            onAdd: { print("Add tapped") }
        )
        
        UserSearchRow(
            user: ProfileData(
                id: "2",
                firstName: "Jane",
                lastName: "Smith",
                email: "jane@example.com",
                profilePhotoURL: nil,
                phoneNumber: "",
                fullNameLower: "jane smith",
                fullName: "Jane Smith",
                fcmToken: nil,
                firebaseUid: nil,
                supabaseUid: nil
            ),
            selectedRole: .viewer,
            isAdding: true,
            onAdd: {}
        )
    }
}
