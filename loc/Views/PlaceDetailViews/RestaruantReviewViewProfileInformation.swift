import SwiftUI

struct RestaruantReviewViewProfileInformation: View {
    let review: ReviewProtocol
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @State private var showProfileView = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) { // Increased spacing between photo and text
            // Profile Photo from Cache
            if let profilePhoto = detailPlaceVM.userProfilePicture[review.userId] {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .onTapGesture {
                        // Check if this is the logged-in user's profile
                        if review.userId == userSession.currentUserId! {
                            // Show the user's own profile page directly
                            showProfileView = true
                        } else {
                            // For other users, fetch and show their profile
                            userProfileViewModel.fetchAndSelectUser(userId: review.userId, currentUserId: userSession.currentUserId!)
                        }
                    }
                    .background(
                        NavigationLink(destination: ProfileView(), isActive: $showProfileView) {
                            EmptyView()
                        }
                    )
            } else if selectedPlaceVM.profilePhotoLoadingState(forUserId: review.userId) == .loading {
                ProgressView()
                    .frame(width: 50, height: 50)
            } else {
                Image(systemName: "person.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(review.userFirstName) \(review.userLastName)")
                    .font(.headline)
                    .foregroundColor(.black)

                Text(formattedTimestamp(review.timestamp))
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Add likes button and count
                HStack(spacing: 4) {
                    Button(action: {
                        selectedPlaceVM.likeReview(review, userId: userSession.currentUserId!)
                    }) {
                        Image(systemName: selectedPlaceVM.isReviewLiked(review.id) ? "heart.fill" : "heart")
                            .foregroundColor(review.userId == userSession.currentUserId! ? .gray : (selectedPlaceVM.isReviewLiked(review.id) ? .red : .gray))
                            .opacity(review.userId == userSession.currentUserId! ? 0.3 : 0.7)
                    }
                    .disabled(review.userId == userSession.currentUserId!)
                    
                    Text("\(review.likes)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 15)
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

    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
