//
//  UserRow.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct UserRow: View {
    let user: ProfileData
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var userProfileVM: UserProfileViewModel
    
    var body: some View {
        NavigationLink(destination: {
            UserProfileView(
                userId: user.id,
                UserProfileVM: userProfileVM
            )
            .environmentObject(profile)
            .environmentObject(detailPlaceVM)
            .environmentObject(userSession) // Add userSession for currentUserId
            .task {
                // Set up user in ViewModel when profile view appears
                // MVVM: ViewModel manages user data state
                // Using .task instead of .onAppear ensures this runs before view renders
                // NOTE: Pass shouldPresent: false to prevent double navigation since NavigationLink handles it
                guard let currentUserId = userSession.currentUserId else { return }
                userProfileVM.selectUser(user, currentUserId: currentUserId, shouldPresent: false)
            }
        }) {
            HStack(spacing: 12) {
                // User profile photo
                if let profileImage = detailPlaceVM.userProfilePicture[user.id] {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .foregroundColor(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(user.fullName.prefix(1))
                                .foregroundColor(.gray)
                        )
                }
                
                // User name
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Additional user info could go here in the future
                }
                
                Spacer()
                
                // Removed manual chevron - NavigationLink provides one automatically
            }
            .padding(.vertical, 8)
        }
    }
}
