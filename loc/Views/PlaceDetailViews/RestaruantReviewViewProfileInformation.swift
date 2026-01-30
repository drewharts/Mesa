import SwiftUI

struct PostProfileInformationView: View {
    let post: PlacePost
    @ObservedObject var photosViewModel: PlacePhotosViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @State private var shouldNavigateToProfile = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Profile Photo from Cache
            if let profilePhoto = photosViewModel.profilePhoto(forUserId: post.userId) {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .onTapGesture {
                        guard let currentUserId = userSession.currentUserId else { return }

                        if post.userId == currentUserId {
                            shouldNavigateToProfile = true
                        } else {
                            userProfileNavigationVM.fetchAndSelectUser(userId: post.userId, currentUserId: currentUserId)
                        }
                    }
            } else if photosViewModel.profilePhotoLoadingState(forUserId: post.userId) == .loading {
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
                Text("\(post.userFirstName) \(post.userLastName)")
                    .font(.headline)
                    .foregroundColor(.black)

                Text(formattedTimestamp(post.timestamp))
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                // Likes button and count
                HStack(spacing: 4) {
                    Button(action: {
                        guard let currentUserId = userSession.currentUserId else { return }
                        selectedPlaceVM.likePost(post, userId: currentUserId)
                    }) {
                        Image(systemName: "heart.fill")
                            .foregroundColor((userSession.currentUserId != nil && post.userId == userSession.currentUserId) ? .gray : (selectedPlaceVM.isPostLiked(post.id) ? .red : .gray))
                            .opacity((userSession.currentUserId != nil && post.userId == userSession.currentUserId) ? 0.3 : 0.7)
                    }
                    .disabled(userSession.currentUserId != nil && post.userId == userSession.currentUserId)
                    
                    Text("\(post.likes)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 15)
        .navigationDestination(isPresented: $shouldNavigateToProfile) {
            ProfileView()
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        let minutes = components.minute ?? 0
        let hours = components.hour ?? 0
        let days = components.day ?? 0
        
        // Handle edge cases (future dates or clock skew)
        if days < 0 || hours < 0 || minutes < 0 {
            return "Just now"
        }
        
        if days == 0 && hours == 0 && minutes < 60 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if days == 0 && hours < 24 {
            return "\(hours)h"
        } else if days > 0 {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}
