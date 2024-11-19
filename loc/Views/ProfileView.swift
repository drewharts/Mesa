//
//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userSession: UserSession // Access UserSession as an environment object

    var body: some View {
        VStack(spacing: 20) {
            // Profile Photo
            if let profilePhotoURL = userSession.user?.profilePhotoURL {
                AsyncImage(url: profilePhotoURL) { image in
                    image.resizable()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.blue)
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .padding(.top, 40)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.top, 40)
            }

            // Name
            Text("\(userSession.user?.firstName ?? "") \(userSession.user?.lastName ?? "")")
                .font(.title)
                .fontWeight(.bold)

            // Email
            Text(userSession.user?.email ?? "")
                .foregroundColor(.gray)
                .font(.subheadline)

            Divider().padding(.horizontal, 40)

            // Place Lists (if you have any logic for place lists)
            // ...

            Spacer()

            // Logout Button
            Button(action: {
                userSession.logout() // Call the logout function
            }) {
                Text("Log Out")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
}
