//
//  ProfilePictureView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/28/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct ProfilePictureView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showingImagePicker = false
    @State private var showingFullScreen = false
    @State private var inputImage: [UIImage] = []
    
    var body: some View {
        Group {
            if let profilePhoto = profile.userPicture {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .onTapGesture {
                        showingFullScreen = true
                    }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.blue)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .onTapGesture {
                        showingImagePicker = true
                    }
            }
        }
        .contextMenu {
            Button {
                showingImagePicker = true
            } label: {
                Label("Change Photo", systemImage: "photo")
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .onChange(of: inputImage) { _ in
            if let newImage = inputImage.first {
                Task {
                    await profile.changeProfilePhoto(newImage)
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let profilePhoto = profile.userPicture {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    Image(uiImage: profilePhoto)
                        .resizable()
                        .scaledToFit()
                        .padding()
                    
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
}

