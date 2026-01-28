//
//  NestedProfileFollowCountsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/26/25.
//
//  For the NESTED NAVIGATION path: Uses @ObservedObject ExternalUserProfileViewModel.
//  ExternalUserProfileViewWrapper creates a @StateObject for each profile in the stack.
//

import SwiftUI

struct NestedProfileFollowCountsView: View {
    @ObservedObject var viewModel: ExternalUserProfileViewModel
    @EnvironmentObject var profileVM: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileVM: UserProfileViewModel

    var body: some View {
        HStack(spacing: 24) {
            // Followers count - NavigationLink
            NavigationLink(destination: NestedFollowersListView(viewModel: viewModel)
                .environmentObject(profileVM)
                .environmentObject(detailPlaceVM)
                .environmentObject(userSession)
                .environmentObject(selectedPlaceVM)
                .environmentObject(userProfileVM)
            ) {
                VStack {
                    Text("\(viewModel.followers)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .fontWeight(.regular)
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Following count - NavigationLink
            NavigationLink(destination: NestedFollowingListView(viewModel: viewModel)
                .environmentObject(profileVM)
                .environmentObject(detailPlaceVM)
                .environmentObject(userSession)
                .environmentObject(selectedPlaceVM)
                .environmentObject(userProfileVM)
            ) {
                VStack {
                    Text("\(viewModel.followingCount)")
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
