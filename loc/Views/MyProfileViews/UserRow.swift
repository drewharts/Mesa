//
//  UserRow.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct UserRow: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    let user: ProfileData
    @EnvironmentObject var userProfileVM: UserProfileViewModel
    
    var body: some View {
        Button(action: {
            guard let currentUserId = userSession.currentUserId else { return }
            userProfileVM.selectUser(user, currentUserId: currentUserId)
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
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.footnote)
            }
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
    }
}
