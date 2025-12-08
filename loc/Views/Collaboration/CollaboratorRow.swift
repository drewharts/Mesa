//
//  CollaboratorRow.swift
//  loc
//
//  DUMB Component: Displays a single collaborator
//  Single Responsibility: Visual display of collaborator data
//

import SwiftUI

struct CollaboratorRow: View {
    let collaborator: LightweightCollaborator
    let isOwner: Bool
    let onRemove: (() -> Void)?
    let onRoleChange: ((CollaboratorRole) -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            profileImage
            userInfo
            Spacer()
            roleControls
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Profile Image
    
    private var profileImage: some View {
        AsyncImage(url: URL(string: collaborator.profilePhotoUrl ?? "")) { phase in
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
                Text(collaborator.displayName.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(.gray)
            )
    }
    
    // MARK: - User Info
    
    private var userInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(collaborator.displayName)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(collaborator.collaboratorRole.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Role Controls
    
    @ViewBuilder
    private var roleControls: some View {
        if isOwner, let onRemove = onRemove {
            ownerMenu(onRemove: onRemove)
        } else {
            roleIcon
        }
    }
    
    private func ownerMenu(onRemove: @escaping () -> Void) -> some View {
        Menu {
            // Remove option (no role change needed - all collaborators are editors)
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "person.badge.minus")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
    
    private var roleIcon: some View {
        Image(systemName: collaborator.collaboratorRole.icon)
            .font(.body)
            .foregroundColor(.secondary)
    }
}

// MARK: - Preview

#Preview {
    List {
        CollaboratorRow(
            collaborator: LightweightCollaborator(
                id: "1",
                userId: "user1",
                role: "editor",
                userName: "John Doe",
                profilePhotoUrl: nil
            ),
            isOwner: true,
            onRemove: { print("Remove tapped") },
            onRoleChange: { print("Role changed to \($0)") }
        )
        
        CollaboratorRow(
            collaborator: LightweightCollaborator(
                id: "2",
                userId: "user2",
                role: "viewer",
                userName: "Jane Smith",
                profilePhotoUrl: nil
            ),
            isOwner: false,
            onRemove: nil,
            onRoleChange: nil
        )
    }
}
