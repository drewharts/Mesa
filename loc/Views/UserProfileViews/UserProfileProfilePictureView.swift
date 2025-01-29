//
//  UserProfileProfilePictureView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileProfilePictureView: View {
    let profilePhotoURL: URL?
    
    var body: some View {
        // The main image or placeholder
        let profileImage: some View = Group {
            if let profilePhotoURL = profilePhotoURL {
                AsyncImage(url: profilePhotoURL) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        
        // Overlay the follow button at the top trailing corner
        profileImage
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .shadow(radius: 4)
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    // Follow action here
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
