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

                Divider()

                // Lists Section
//                VStack(alignment: .leading) {
//                    Text("LISTS")
//                        .font(.headline)
//                        .padding(.horizontal, 16)
//
//                    ForEach(userSession.profileViewModel?.data.placeLists ?? []) { list in
//                        NavigationLink(destination: PlaceListView(placeList: list)) {
//                            HStack {
//                                Rectangle() // Placeholder for list image
//                                    .frame(width: 60, height: 60)
//                                    .foregroundColor(.gray)
//                                VStack(alignment: .leading) {
//                                    Text(list.name)
//                                        .font(.body)
//                                    Text("\(list.itemCount) Places")
//                                        .font(.caption)
//                                        .foregroundColor(.gray)
//                                }
//                                Spacer()
//                            }
//                            .padding()
//                        }
//                        .background(Color(.secondarySystemBackground))
//                        .cornerRadius(8)
//                        .padding(.horizontal, 16)
//                    }
//                }
            }
            .padding(.bottom, 40) // Space for scrollable content
        }
        .background(Color(.systemBackground))
        .navigationBarTitle("Profile", displayMode: .inline)
    }
}
