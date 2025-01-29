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
                if let profilePhotoURL = user.profilePhotoURL {
                    AsyncImage(url: profilePhotoURL) { image in
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                            .foregroundColor(.gray)
                    }
                }

                // Name
                Text("\(user.firstName) \(user.lastName)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Divider()
                    .padding(.horizontal, 20)

                // Email (Optional)
                if !user.email.isEmpty {
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Phone Number (Optional)
                if !user.phoneNumber.isEmpty {
                    Text(user.phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // User's Place Lists
                UserPlaceListsView(placeLists: user.placeLists)

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
