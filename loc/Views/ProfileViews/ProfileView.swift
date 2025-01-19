//
//  ProfileView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var profile: ProfileViewModel
    
    var btnBack : some View { Button(action: {
        self.presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
            Image(systemName: "chevron.left") // set image here
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.black)
            }
        }
    }

    var body: some View {
        NavigationView {
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
                        .foregroundStyle(.black)
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.horizontal, 20)
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
                }
                .padding(.bottom, 40)
                .padding(.top,-30)
            }
            .background(Color(.white))
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
    }
}
