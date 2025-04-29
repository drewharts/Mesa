import SwiftUI
import UIKit

struct InlineCommentsView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @State private var commentText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var isPickerPresented = false
    @State private var showingReplyField = false
    @State private var loadedCommentLimit = 5
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    @Binding var selectedImage: UIImage?
    
    let reviewId: String
    let onKeyboardActive: (Bool) -> Void
    
    init(reviewId: String, selectedImage: Binding<UIImage?>, onKeyboardActive: @escaping (Bool) -> Void) {
        self.reviewId = reviewId
        self._selectedImage = selectedImage
        self.onKeyboardActive = onKeyboardActive
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Comments list
            ForEach(selectedPlaceVM.comments(forReviewId: reviewId).prefix(loadedCommentLimit), id: \.id) { comment in
                CommentView(comment: comment, selectedImage: $selectedImage)
            }
            
            // Load more button if there are more comments
            if selectedPlaceVM.comments(forReviewId: reviewId).count > loadedCommentLimit {
                Button("Load more comments") {
                    loadedCommentLimit += 5
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.top, 8)
            }
            
            // Comment input field
            if showingReplyField {
                HStack(alignment: .bottom) {
                    if let userPhoto = userProfileViewModel.userProfilePhotos[profile.userId] {
                        Image(uiImage: userPhoto)
                            .resizable()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Write a comment...", text: $commentText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                        
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedImages, id: \.self) { image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        if !commentText.isEmpty || !selectedImages.isEmpty {
                            selectedPlaceVM.addComment(
                                reviewId: reviewId,
                                text: commentText,
                                images: selectedImages,
                                userId: profile.userId,
                                userName: profile.data.firstName + " " + profile.data.lastName
                            )
                            commentText = ""
                            selectedImages = []
                            showingReplyField = false
                            isTextFieldFocused = false
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(commentText.isEmpty && selectedImages.isEmpty)
                }
                .padding(.top, 8)
            }
        }
        .padding(.top, 8)
        .onChange(of: isTextFieldFocused) { isFocused in
            onKeyboardActive(isFocused)
        }
    }
} 