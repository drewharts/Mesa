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
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Picture
                ProfilePictureView()

                // Name
                let firstName = profile.data.firstName
                let lastName = profile.data.lastName
                Text("\(firstName) \(lastName)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
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
            .padding(.top, 10)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left") // Custom back icon
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.black)
                        Text("Back") // Optional: Add text next to the icon
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}
