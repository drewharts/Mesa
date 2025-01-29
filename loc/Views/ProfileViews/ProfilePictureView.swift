//
//  ProfilePictureView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/28/25.
//

import SwiftUI

struct ProfilePictureView: View {
    @EnvironmentObject var profile: ProfileViewModel
    
    var body: some View {
        // The main image or placeholder
        let profileImage: some View = Group {
            if let profilePhoto = profile.profilePhoto {
                profilePhoto
                    .resizable()
                    .frame(width: 120, height: 120)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.blue)
                    .frame(width: 120, height: 120)
            }
        }
        
        // Overlay the button at the bottom trailing corner of the image
        profileImage
            .clipShape(Circle())
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    // follow action
                }) {
                    Image(systemName: "person.fill.badge.plus")
                        .padding(6)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .padding(4)
            }
            .padding(.top, 40)
    }
}

