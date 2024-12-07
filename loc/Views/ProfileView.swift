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
        NavigationView {
            VStack(spacing: 20) {
                
                // Profile Photo
                if let profilePhoto = userSession.profile?.profilePhoto {
                    profilePhoto
                        .resizable()
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

                // Display Name
                let firstName = userSession.profile?.data.firstName ?? ""
                let lastName = userSession.profile?.data.lastName ?? ""
                Text("\(firstName) \(lastName)")
                    .font(.title)
                    .fontWeight(.bold)

                // Email
                let email = userSession.profile?.data.email ?? ""
                Text(email)
                    .foregroundColor(.gray)
                    .font(.subheadline)

                Divider().padding(.horizontal, 40)

                // Place Lists Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Lists")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    // Extract placeLists to a local constant
                    let placeLists = userSession.profile?.data.placeLists ?? []

                    List(placeLists) { list in
                        NavigationLink(destination: PlaceListView(placeList: list)) {
                            Text(list.name)
                                .font(.body)
                        }
                    }
                }

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
            .navigationBarTitle("Profile", displayMode: .inline)
        }
    }
}
