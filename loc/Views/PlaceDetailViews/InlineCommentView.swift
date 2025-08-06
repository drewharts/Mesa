import SwiftUI

struct InlineCommentView: View {
    let comment: loc.Comment
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var detailplaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @State private var showFullText = false
    @State private var shouldNavigateToProfile = false
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // User info and comment text
            HStack(alignment: .top, spacing: 8) {
                // First try to get the profile photo from cache
                if let cachedPhoto = detailplaceVM.userProfilePicture[comment.userId] {
                    Image(uiImage: cachedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                        .onTapGesture {
                            // Check if this is the logged-in user's profile
                            guard let currentUserId = userSession.currentUserId else { return }
                            
                            if comment.userId == currentUserId {
                                // Show the user's own profile page directly
                                shouldNavigateToProfile = true
                            } else {
                                // For other users, fetch and show their profile
                                userProfileViewModel.fetchAndSelectUser(userId: comment.userId, currentUserId: currentUserId)
                            }
                        }
                // If not in cache, use AsyncImage as fallback
                } else if let url = URL(string: comment.profilePhotoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Image(systemName: "person.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                                .foregroundColor(.gray)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                                .onTapGesture {
                                    // Check if this is the logged-in user's profile
                                    guard let currentUserId = userSession.currentUserId else { return }
                                    
                                    if comment.userId == currentUserId {
                                        // Show the user's own profile page directly
                                        shouldNavigateToProfile = true
                                    } else {
                                        // For other users, fetch and show their profile
                                        userProfileViewModel.fetchAndSelectUser(userId: comment.userId, currentUserId: currentUserId)
                                    }
                                }
                        case .failure:
                            Image(systemName: "person.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .foregroundColor(.gray)
                        .onTapGesture {
                            // Check if this is the logged-in user's profile
                            guard let currentUserId = userSession.currentUserId else { return }
                            
                            if comment.userId == currentUserId {
                                // Show the user's own profile page directly  
                                shouldNavigateToProfile = true
                            } else {
                                // For other users, fetch and show their profile
                                userProfileViewModel.fetchAndSelectUser(userId: comment.userId, currentUserId: currentUserId)
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(comment.userFirstName) \(comment.userLastName)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary) // Use .primary for dark mode support
                        
                        Text(formattedTimestamp(comment.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Like button removed
                    }
                    
                    // Comment text
                    Text(comment.commentText)
                        .font(.caption)
                        .foregroundColor(.primary) // Use .primary for dark mode support
                        .lineLimit(showFullText ? nil : 3)
                        .onTapGesture {
                            withAnimation {
                                showFullText.toggle()
                            }
                        }
                }
            }
            
            // Show photos if any (smaller)
            let photos = selectedPlaceVM.commentPhotos(for: comment)
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            Image(uiImage: photos[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                )
                                .onTapGesture {
                                    onPhotoTapped(photos, index)
                                }
                                .shadow(radius: 1)
                        }
                    }
                }
                .frame(height: 60)
                .padding(.leading, 32) // Aligns with the text
            }
        }
        .navigationDestination(isPresented: $shouldNavigateToProfile) {
            ProfileView()
        }
    }
    
    // Helper function to format timestamp
    private func formattedTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let minutes = components.minute, minutes < 60 && (components.hour ?? 0) == 0 && (components.day ?? 0) == 0 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if let hours = components.hour, hours < 24 && (components.day ?? 0) == 0 {
            return "\(hours)h"
        } else if let days = components.day {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}
