//
//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var profile: ProfileViewModel


    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Picture
                if let profilePhoto = profile.profilePhoto {
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
                let firstName = profile.data.firstName
                let lastName = profile.data.lastName
                Text("\(firstName) \(lastName)")
                    .font(.title)
                    .fontWeight(.bold)

                // Favorites & Lists
                ProfileFavoriteListView()
                ProfileViewListsView()


                // Logout Button
                Button(action: {
                    userSession.logout()
                }) {
                    Text("Log Out")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
            .padding(.bottom, 40) // Space for scrollable content
        }
        .background(Color(.systemBackground))
        .navigationBarTitle("Profile", displayMode: .inline)
    }
}
