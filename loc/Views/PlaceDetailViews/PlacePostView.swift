//
//  PlacePostView.swift
//  loc
//
//  Displays a single post in the place feed
//

import SwiftUI

struct PlacePostView: View {
    let post: PlacePost
    @ObservedObject var viewModel: PlacePostsViewModel
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession
    
    private var postPhotos: [UIImage] {
        viewModel.getPhotos(for: post)
    }
    
    private var loadingState: PlacePhotosViewModel.LoadingState {
        viewModel.getPhotoLoadingState(for: post)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header: Profile Picture, Name, Timestamp, and Sentiment
            headerSection
            
            // Post Text (if any)
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Photos
            photoSection
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            // Profile Photo
            profilePhoto
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(post.userFirstName) \(post.userLastName)")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    // Sentiment badge
                    if let wouldReturn = post.wouldReturn {
                        sentimentBadge(wouldReturn: wouldReturn)
                    }
                }
                
                Text(formattedTimestamp(post.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Likes
                likesSection
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var profilePhoto: some View {
        if let profilePhoto = viewModel.photosViewModel.profilePhoto(forUserId: post.userId) {
            Image(uiImage: profilePhoto)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .onTapGesture {
                    navigateToProfile()
                }
        } else if viewModel.photosViewModel.profilePhotoLoadingState(forUserId: post.userId) == .loading {
            ProgressView()
                .frame(width: 44, height: 44)
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundColor(.gray)
        }
    }
    
    private func sentimentBadge(wouldReturn: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: wouldReturn ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .font(.caption2)
            Text(wouldReturn ? "Would go back" : "Wouldn't revisit")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(wouldReturn ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(wouldReturn ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var likesSection: some View {
        HStack(spacing: 4) {
            Button(action: {
                guard let currentUserId = userSession.currentUserId else { return }
                selectedPlaceVM.likePost(post, userId: currentUserId)
            }) {
                Image(systemName: "heart.fill")
                    .foregroundColor(isOwnPost ? .gray : (selectedPlaceVM.isPostLiked(post.id) ? .red : .gray))
                    .opacity(isOwnPost ? 0.3 : 0.7)
            }
            .disabled(isOwnPost)
            
            Text("\(post.likes)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var isOwnPost: Bool {
        userSession.currentUserId != nil && post.userId == userSession.currentUserId
    }
    
    // MARK: - Photo Section
    
    @ViewBuilder
    private var photoSection: some View {
        switch loadingState {
        case .loading:
            VStack {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading photos...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .frame(height: 150)
            
        case .loaded:
            if !postPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(postPhotos.enumerated()), id: \.offset) { index, photo in
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 150, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 2)
                                .onTapGesture {
                                    onPhotoTapped(postPhotos, index)
                                }
                                .onAppear {
                                    if index == postPhotos.count - 1 {
                                        viewModel.loadMorePhotos(for: post.id, allImageUrls: post.images)
                                    }
                                }
                        }
                    }
                }
            }
            
        case .error(let error):
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Failed to load photos")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button(action: {
                    viewModel.reloadPhotos(for: post)
                }) {
                    Text("Retry")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding()
            
        case .idle:
            if !post.images.isEmpty {
                ProgressView()
                    .padding()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func navigateToProfile() {
        guard let currentUserId = userSession.currentUserId else { return }

        if post.userId != currentUserId {
            userProfileNavigationVM.fetchAndSelectUser(userId: post.userId, currentUserId: currentUserId)
        }
    }
    
    private func formattedTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        let minutes = components.minute ?? 0
        let hours = components.hour ?? 0
        let days = components.day ?? 0
        
        // Handle edge cases (future dates or clock skew)
        if days < 0 || hours < 0 || minutes < 0 {
            return "Just now"
        }
        
        if days == 0 && hours == 0 && minutes < 60 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if days == 0 && hours < 24 {
            return "\(hours)h"
        } else if days > 0 {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

