//
//  UserProfileProfilePictureView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileProfilePictureView: View {
    let profilePhotoURL: URL?

    // MARK: - Constants
    private let profileSize: CGFloat = 96

    @State private var showingFullScreen = false

    var body: some View {
        profileImageView
            .frame(width: profileSize, height: profileSize)
            .clipShape(Circle())
            .shadow(radius: 4)
            .onTapGesture {
                if profilePhotoURL != nil {
                    showingFullScreen = true
                }
            }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let url = profilePhotoURL {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)

                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .padding()
                    } placeholder: {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }

                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                showingFullScreen = false
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var profileImageView: some View {
        Group {
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
    }
}
