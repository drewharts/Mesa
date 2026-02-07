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
    @State private var showingPlacesCount = false
    @State private var inputImage: [UIImage] = []
    @State private var hasProcessedImage = false
    
    // MARK: - Constants
    private let profileSize: CGFloat = 100
    
    // MARK: - Subtle Places Count Badge (Apple-style)
    private var placesCountBadge: some View {
        let count = profile.totalUniquePlacesCount
        let displayText = count >= 1000 ? "\(count / 1000)k+" : "\(count)"
        
        return Button(action: {
            showingPlacesCount = true
        }) {
            Text(displayText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(minWidth: 24)  // Ensures badge extends past circle edge for single digits
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .offset(x: 8, y: 4)
    }
    
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
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.blue)
                        .frame(width: profileSize, height: profileSize)
                        .clipShape(Circle())
                        .shadow(radius: 4)
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
            
            // Places count badge - inline implementation (no separate file needed)
            if profile.totalUniquePlacesCount > 0 {
                placesCountBadge
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
        .alert("Places Saved", isPresented: $showingPlacesCount) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You have \(profile.totalUniquePlacesCount) places saved across all your lists, favorites, and reviews.")
        }
    }
}

