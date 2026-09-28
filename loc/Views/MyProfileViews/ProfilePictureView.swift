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
    @State private var hasProcessedImage = false

    // MARK: - Constants
    private let profileSize: CGFloat = 96

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main profile image
            Group {
                if let profilePhoto = profile.userPicture {
                    Image(uiImage: profilePhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: profileSize, height: profileSize)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.blue)
                            .frame(width: profileSize, height: profileSize)
                            .clipShape(Circle())
                            .shadow(radius: 4)

                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .background(Circle().fill(.white).frame(width: 20, height: 20))
                            .offset(x: -4, y: -4)
                    }
                }
            }
            .onTapGesture {
                if !profile.isUploadingProfilePhoto {
                    // If user has no profile picture, prompt them to add one
                    if profile.userPicture == nil {
                        showingImagePicker = true
                    } else {
                        showingFullScreen = true
                    }
                }
            }
            .contextMenu {
                if !profile.isUploadingProfilePhoto {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Change Photo", systemImage: "photo")
                    }
                }
            }
            
            // Loading overlay
            if profile.isUploadingProfilePhoto {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: profileSize, height: profileSize)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    )
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .onChange(of: inputImage) { oldValue, newValue in
            // Prevent multiple processing of the same image
            guard !newValue.isEmpty, !hasProcessedImage, let newImage = newValue.first else { return }
            
            hasProcessedImage = true
            
            // Start upload - ProfileViewModel handles loading state
            Task {
                await profile.changeProfilePhoto(newImage)
                
                // Reset local state after upload completes
                await MainActor.run {
                    hasProcessedImage = false
                    inputImage.removeAll() // Clear the processed image
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

