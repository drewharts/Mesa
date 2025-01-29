//
//  UserProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileView: View {
    let user: ProfileData
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Picture
                UserProfileProfilePictureView(profilePhotoURL: user.profilePhotoURL)

                // Name
                Text(user.fullName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Divider()
                    .padding(.horizontal, 20)

                // User's Place Lists
//                UserPlaceListsView(placeLists: user.placeLists)

                Spacer()
            }
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.black)
                        Text("Back")
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

// A simple view for displaying the user's place lists
struct UserPlaceListsView: View {
    let placeLists: [PlaceList]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Place Lists")
                .font(.headline)
                .padding(.leading, 20)
            
            if placeLists.isEmpty {
                Text("No lists available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            } else {
                ForEach(placeLists, id: \.name) { list in
                    HStack {
                        Text(list.name)
                            .foregroundColor(.blue)
                            .padding()
                        Spacer()
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
