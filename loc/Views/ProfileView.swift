//
//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Picture
                if let profilePhoto = userSession.profileViewModel?.profilePhoto {
                    profilePhoto
                        .resizable()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .padding(.top, 40)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                }

                // Name
                let firstName = userSession.profileViewModel?.data.firstName ?? "First Name"
                let lastName = userSession.profileViewModel?.data.lastName ?? "Last Name"
                Text("\(firstName) \(lastName)")
                    .font(.title)
                    .fontWeight(.bold)

                // Email
                let email = userSession.profileViewModel?.data.email ?? "example@example.com"
                Text(email)
                    .foregroundColor(.gray)
                    .font(.subheadline)

                ProfileFavoriteListView()
                ProfileViewListsView()
            }
            .padding(.bottom, 40) // Space for scrollable content
        }
        .background(Color(.systemBackground))
        .navigationBarTitle("Profile", displayMode: .inline)
    }
}
