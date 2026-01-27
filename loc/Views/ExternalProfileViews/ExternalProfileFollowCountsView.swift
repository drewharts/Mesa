//
//  ExternalProfileFollowCountsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/26/25.
//
//  For the DEEP LINK path: Uses @EnvironmentObject UserProfileViewModel.
//  UserProfileView injects UserProfileVM as an environment object.
//

import SwiftUI

struct ExternalProfileFollowCountsView: View {
    @EnvironmentObject var userProfileVM: UserProfileViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        HStack(spacing: 24) {
            // Followers count - NavigationLink
            NavigationLink(destination: ExternalFollowersListView()
                .environmentObject(userProfileVM)
                .environmentObject(profileVM)
                .environmentObject(detailPlaceVM)
                .environmentObject(userSession)
                .environmentObject(selectedPlaceVM)
            ) {
                VStack {
                    Text("\(userProfileVM.followers)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .fontWeight(.regular)
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Following count - NavigationLink
            NavigationLink(destination: ExternalFollowingListView()
                .environmentObject(userProfileVM)
                .environmentObject(profileVM)
                .environmentObject(detailPlaceVM)
                .environmentObject(userSession)
                .environmentObject(selectedPlaceVM)
            ) {
                VStack {
                    Text("\(userProfileVM.followingCount)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .fontWeight(.regular)
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 10)
    }
}
