import SwiftUI

struct ProfileCirclesView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    let placeId: String?
    
    var body: some View {
        Group {
            if let placeId = placeId {
                // Get unique users who saved this place, excluding current user
                let uniqueUsers = profile.getUniquePlaceSaversExcludingCurrentUser(forPlaceId: placeId)
                
                // Only show the profile circles if we actually have other unique users
                if !uniqueUsers.isEmpty {
                    HStack(spacing: -10) {
                        // Get profile images for this place (we'll still use getFirstThreeProfileImages since
                        // it pulls from DetailPlaceViewModel.placeSavers which has the correct filtering)
                        let (image1, image2, image3) = getProfileImagesForDisplayedUsers(users: uniqueUsers, placeId: placeId)
                        
                        // First profile image
                        if let image1 = image1 {
                            profileCircleImage(image: image1)
                        }
                        
                        // Second profile image
                        if let image2 = image2 {
                            profileCircleImage(image: image2)
                        }
                        
                        // Third or +more indicator
                        if let image3 = image3 {
                            profileCircleImage(image: image3)
                        } else if uniqueUsers.count > 2 {
                            // Show +X if there are more than shown
                            plusCircle(count: uniqueUsers.count - 2)
                        }
                    }
                }
            } else {
                // If no users have saved this place, display nothing
                EmptyView()
            }
        }
    }
    
    // Helper method to get profile images for displayed users
    private func getProfileImagesForDisplayedUsers(users: [ProfileData], placeId: String) -> (UIImage?, UIImage?, UIImage?) {
        guard !users.isEmpty else { return (nil, nil, nil) }
        
        let firstThreeUsers = users.prefix(3)
        let images = firstThreeUsers.map { user -> UIImage? in
            detailPlaceViewModel.userProfilePicture[user.id]
        }
        
        let paddedImages = (images + [nil, nil, nil]).prefix(3)
        return (paddedImages[0], paddedImages[1], paddedImages[2])
    }
    
    // Helper view for profile image circle
    private func profileCircleImage(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 30, height: 30)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.white, lineWidth: 2)
            )
    }
    
    // Helper view for the +X circle
    private func plusCircle(count: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.gray)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )
            
            Text("+\(count)")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}
