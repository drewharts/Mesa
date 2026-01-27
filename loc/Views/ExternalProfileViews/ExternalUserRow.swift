//
//  ExternalUserRow.swift
//  loc
//
//  User row for external profile navigation. Uses ExternalUserProfileViewWrapper
//  to create independent ViewModel instances for each profile in the navigation stack.
//

import SwiftUI

/// User row for nested profile navigation within external profiles.
/// Each row navigates to ExternalUserProfileViewWrapper which creates its own @StateObject ViewModel.
struct ExternalUserRow: View {
    let user: ProfileData

    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        NavigationLink(destination: {
            ExternalUserProfileViewWrapper(user: user)
                .id(user.id)  // Force new view identity when user changes
                .environmentObject(profile)
                .environmentObject(detailPlaceVM)
                .environmentObject(userSession)
                .environmentObject(selectedPlaceVM)
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
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}
