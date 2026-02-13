//
//  PlacePostView.swift
//  loc
//
//  Displays a single post in the place feed
//

import SwiftUI

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct PlacePostView: View {
    let post: PlacePost
    @ObservedObject var viewModel: PlacePostsViewModel
    let onPhotoTapped: ([String], Int) -> Void

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var userSession: UserSession

    @State private var fullscreenVideoURL: URL?

    private var mediaWidth: CGFloat {
        UIScreen.main.bounds.width - 56
    }

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
            
            // Media (photos + videos)
            mediaSection
        }
        .padding(.vertical, 12)
        .fullScreenCover(item: $fullscreenVideoURL) { url in
            FullscreenVideoPlayerView(url: url)
        }
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
    
    // MARK: - Media Section

    private var hasMedia: Bool {
        !post.images.isEmpty || !post.videoUrls.isEmpty
    }

    @ViewBuilder
    private var mediaSection: some View {
        switch loadingState {
        case .loading:
            mediaLoadingView

        case .loaded:
            loadedMediaContent

        case .error:
            mediaErrorView

        case .idle:
            if hasMedia {
                ProgressView().padding()
            }
        }
    }

    private var mediaLoadingView: some View {
        VStack {
            ProgressView().scaleEffect(1.2)
            Text("Loading media...")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(height: 250)
    }

    @ViewBuilder
    private var loadedMediaContent: some View {
        let photos = postPhotos

        if !photos.isEmpty || !post.videoUrls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    // Image items (backed by loaded UIImages)
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        imageMediaCell(photo: photo, index: index)
                    }
                    // Video items
                    ForEach(Array(post.videoUrls.enumerated()), id: \.element) { index, videoUrlString in
                        let thumbnail = index < post.videoThumbnailUrls.count ? post.videoThumbnailUrls[index] : nil
                        videoMediaCell(urlString: videoUrlString, thumbnailUrlString: thumbnail)
                    }
                }
            }
        }
    }

    private func imageMediaCell(photo: UIImage, index: Int) -> some View {
        Image(uiImage: photo)
            .resizable()
            .scaledToFill()
            .frame(width: mediaWidth, height: mediaWidth)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 2)
            .onTapGesture {
                onPhotoTapped(post.images, index)
            }
            .onAppear {
                if index == postPhotos.count - 1 {
                    viewModel.loadMorePhotos(for: post.id, allImageUrls: post.images)
                }
            }
    }

    @ViewBuilder
    private func videoMediaCell(urlString: String, thumbnailUrlString: String?) -> some View {
        if let videoURL = URL(string: urlString) {
            let thumbURL = thumbnailUrlString.flatMap { URL(string: $0) }
            InlineVideoPlayerView(url: videoURL, thumbnailURL: thumbURL) {
                fullscreenVideoURL = videoURL
            }
            .frame(width: mediaWidth, height: mediaWidth)
            .shadow(radius: 2)
        }
    }

    private var mediaErrorView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("Failed to load media")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Button(action: { viewModel.reloadPhotos(for: post) }) {
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

