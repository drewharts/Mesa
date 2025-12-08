//
//  CollaboratorAvatarStack.swift
//  loc
//
//  A DUMB component that displays overlapping profile picture avatars
//  Single Responsibility: Visual display of stacked avatars
//

import SwiftUI

struct CollaboratorAvatarStack: View {
    let ownerPhotoUrl: String?
    let ownerName: String?
    let collaboratorPhotos: [String]?
    let size: CGFloat
    let maxVisible: Int
    
    /// Additional collaborators beyond maxVisible
    private var extraCount: Int {
        let total = (collaboratorPhotos?.count ?? 0)
        return max(0, total - maxVisible + 1)
    }
    
    /// Photos to display (owner + collaborators up to maxVisible)
    private var visiblePhotos: [String?] {
        var photos: [String?] = [ownerPhotoUrl]
        if let collabPhotos = collaboratorPhotos {
            let availableSlots = maxVisible - 1
            photos.append(contentsOf: collabPhotos.prefix(availableSlots).map { $0 as String? })
        }
        return photos
    }
    
    init(
        ownerPhotoUrl: String?,
        ownerName: String? = nil,
        collaboratorPhotos: [String]? = nil,
        size: CGFloat = 28,
        maxVisible: Int = 4
    ) {
        self.ownerPhotoUrl = ownerPhotoUrl
        self.ownerName = ownerName
        self.collaboratorPhotos = collaboratorPhotos
        self.size = size
        self.maxVisible = maxVisible
    }
    
    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(visiblePhotos.enumerated()), id: \.offset) { index, photoUrl in
                avatarView(photoUrl: photoUrl, isOwner: index == 0)
                    .zIndex(Double(visiblePhotos.count - index))
            }
            
            if extraCount > 0 {
                extraCountBadge
                    .zIndex(0)
            }
        }
    }
    
    // MARK: - Avatar View
    
    private func avatarView(photoUrl: String?, isOwner: Bool) -> some View {
        AsyncImage(url: URL(string: photoUrl ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Circle()
                    .fill(isOwner ? Color.blue.opacity(0.3) : Color.gray.opacity(0.3))
                    .overlay(
                        Text(isOwner ? (ownerName?.prefix(1).uppercased() ?? "?") : "?")
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundColor(isOwner ? .blue : .gray)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 2)
        )
    }
    
    // MARK: - Extra Count Badge
    
    private var extraCountBadge: some View {
        Circle()
            .fill(Color.gray.opacity(0.8))
            .frame(width: size, height: size)
            .overlay(
                Text("+\(extraCount)")
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(Color(.systemBackground), lineWidth: 2)
            )
    }
}

// MARK: - Compact Version for List Cards

struct SharedByBadge: View {
    let ownerName: String
    let ownerPhotoUrl: String?
    
    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: URL(string: ownerPhotoUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            Text(ownerName.prefix(1).uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.blue)
                        )
                }
            }
            .frame(width: 20, height: 20)
            .clipShape(Circle())
            
            Text("Shared by \(ownerName.components(separatedBy: " ").first ?? ownerName)")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Previews

#Preview("Avatar Stack") {
    VStack(spacing: 20) {
        // Just owner
        CollaboratorAvatarStack(
            ownerPhotoUrl: nil,
            ownerName: "Sarah"
        )
        
        // Owner + 2 collaborators
        CollaboratorAvatarStack(
            ownerPhotoUrl: nil,
            ownerName: "Sarah",
            collaboratorPhotos: ["url1", "url2"]
        )
        
        // Owner + many collaborators (shows +N)
        CollaboratorAvatarStack(
            ownerPhotoUrl: nil,
            ownerName: "Sarah",
            collaboratorPhotos: ["url1", "url2", "url3", "url4", "url5"]
        )
    }
    .padding()
}

#Preview("Shared By Badge") {
    SharedByBadge(
        ownerName: "Sarah Jones",
        ownerPhotoUrl: nil
    )
    .padding()
}

