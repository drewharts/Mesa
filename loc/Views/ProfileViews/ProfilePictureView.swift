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
        Group {
            if let profilePhoto = profile.profilePhoto {
                profilePhoto
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.blue)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
    }
}

