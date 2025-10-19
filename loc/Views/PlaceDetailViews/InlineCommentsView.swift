import SwiftUI

struct InlineCommentsView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @State private var commentText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var isPickerPresented = false
    @State private var showingReplyField = false
    @State private var loadedCommentLimit = 5
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    let onPhotoTapped: ([UIImage], Int) -> Void
    
    let reviewId: String
    let onKeyboardActive: (Bool) -> Void
    
    init(reviewId: String, onPhotoTapped: @escaping ([UIImage], Int) -> Void, onKeyboardActive: @escaping (Bool) -> Void) {
        self.reviewId = reviewId
        self.onPhotoTapped = onPhotoTapped
        self.onKeyboardActive = onKeyboardActive
    }
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 12) {
                // Comments list
                let comments = selectedPlaceVM.comments(for: reviewId)
                let totalCommentCount = selectedPlaceVM.commentCount(for: reviewId)
                let loadingState = selectedPlaceVM.commentLoadingState(for: reviewId)
                
                switch loadingState {
                case .loading:
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity)
                    
                case .loaded:
                    if comments.isEmpty {
                        Text("No comments yet. Be the first to comment!")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 5)
                        
                        // If no comments, automatically focus the reply field
                        if showingReplyField {
                            // Comment input field
                            HStack(spacing: 10) {
                                // Comment text field with automatic focus
                                TextField("Add a comment...", text: $commentText)
                                    .font(.footnote)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(15)
                                    .foregroundColor(.primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .focused($isTextFieldFocused)
                                    .onAppear {
                                        // ✅ Faster focus to reduce keyboard delay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isTextFieldFocused = true
                                            // Scroll to ensure input field is visible
                                            scrollProxy.scrollTo("commentInputField", anchor: .bottom)
                                        }
                                    }
                                
                                // Submit button
                                Button(action: {
                                    submitComment()
                                    showingReplyField = false
                                    isTextFieldFocused = false
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(commentText.isEmpty && selectedImages.isEmpty ? .gray : .blue)
                                        .font(.footnote)
                                }
                                .disabled(commentText.isEmpty && selectedImages.isEmpty)
                                
                                // Photo button with indicator dot when images are selected
                                Button(action: {
                                    isPickerPresented = true
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "photo")
                                            .foregroundColor(!selectedImages.isEmpty ? .blue : .gray)
                                            .font(.footnote)
                                        
                                        // Show count indicator if images are selected
                                        if !selectedImages.isEmpty {
                                            Text("\(selectedImages.count)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white)
                                                .frame(width: 14, height: 14)
                                                .background(Circle().fill(Color.red))
                                                .offset(x: 8, y: -8)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .id("commentInputField")
                            
                            // Display selected images preview if any
                            if !selectedImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(0..<selectedImages.count, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: selectedImages[index])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                                    )
                                                
                                                // Remove button
                                                Button(action: {
                                                    selectedImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                                        .font(.system(size: 16))
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                }
                                .frame(height: 70)
                                .padding(.bottom, 5)
                            }
                        } else {
                            // Only show reply button when not yet replying
                            HStack(spacing: 8) {
                                // Small horizontal line
                                Rectangle()
                                    .frame(width: 16, height: 1)
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Button(action: {
                                    showingReplyField = true
                                    // ✅ Immediate focus for better responsiveness
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        isTextFieldFocused = true
                                    }
                                }) {
                                    Text("Reply")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 15) // Indent to align
                            .padding(.vertical, 5)
                        }
                    } else {
                        // Show existing comments with spacing
                        VStack(spacing: 16) {
                            ForEach(comments) { comment in
                                HStack(alignment: .top, spacing: 5) {
                                    // Actual comment
                                    InlineCommentView(comment: comment, onPhotoTapped: onPhotoTapped)
                                }
                            }
                            
                            // Load more comments button if there are more to load
                            if comments.count < totalCommentCount {
                                Button(action: {
                                    loadMoreComments()
                                }) {
                                    HStack {
                                        Text("Load more comments")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        Image(systemName: "arrow.down.circle")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 8)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.leading, 8)
                        
                        // Add reply button or comment input field below comments
                        if showingReplyField {
                            // Comment input when reply is clicked
                            HStack(spacing: 10) {
                                // Comment text field
                                TextField("Add a comment...", text: $commentText)
                                    .font(.footnote)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(15)
                                    .foregroundColor(.primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .focused($isTextFieldFocused)
                                    .onChange(of: isTextFieldFocused) {
                                        if isTextFieldFocused {
                                            // Small delay to ensure UI is updated
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                withAnimation {
                                                    // This will trigger our keyboard height adjustment
                                                    showingReplyField = true
                                                    // Scroll to ensure input field is visible
                                                    scrollProxy.scrollTo("commentInputField", anchor: .bottom)
                                                }
                                            }
                                        }
                                    }
                                
                                // Submit button
                                Button(action: {
                                    submitComment()
                                    showingReplyField = false
                                    isTextFieldFocused = false
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(commentText.isEmpty && selectedImages.isEmpty ? .gray : .blue)
                                        .font(.footnote)
                                }
                                .disabled(commentText.isEmpty && selectedImages.isEmpty)
                                
                                // Photo button with indicator dot when images are selected
                                Button(action: {
                                    isPickerPresented = true
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "photo")
                                            .foregroundColor(!selectedImages.isEmpty ? .blue : .gray)
                                            .font(.footnote)
                                        
                                        // Show count indicator if images are selected
                                        if !selectedImages.isEmpty {
                                            Text("\(selectedImages.count)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white)
                                                .frame(width: 14, height: 14)
                                                .background(Circle().fill(Color.red))
                                                .offset(x: 8, y: -8)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .id("commentInputField") // Give it a stable ID for scrolling
                            
                            // Display selected images preview if any
                            if !selectedImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(0..<selectedImages.count, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: selectedImages[index])
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                                                    )
                                                
                                                // Remove button
                                                Button(action: {
                                                    selectedImages.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                                        .font(.system(size: 16))
                                                }
                                                .padding(4)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                }
                                .frame(height: 70)
                                .padding(.bottom, 5)
                            }
                        } else {
                            // Only show reply button when not yet replying
                            HStack(spacing: 8) {
                                // Small horizontal line
                                Rectangle()
                                    .frame(width: 16, height: 1)
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Button(action: {
                                    showingReplyField = true
                                    // ✅ Immediate focus for better responsiveness
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        isTextFieldFocused = true
                                    }
                                }) {
                                    Text("Reply")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                
                                // Add vertical separator and hide button
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 1, height: 14)
                                    .padding(.horizontal, 8)
                                
                                Button(action: {
                                    // Hide comments when clicked
                                    withAnimation {
                                        onKeyboardActive(false)
                                        isTextFieldFocused = false
                                        RestaurantReviewView.hideComments(reviewId: reviewId)
                                    }
                                }) {
                                    Text("Hide")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 15) // Indent to align
                            .padding(.vertical, 5)
                        }
                    }
                    
                case .error(let error):
                    Text("Failed to load comments: \(error.localizedDescription)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.vertical, 5)
                    
                case .idle:
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, showingReplyField ? keyboardHeight : 0)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            .onChange(of: showingReplyField) {
                if showingReplyField {
                    // When reply field is shown, scroll to it
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            scrollProxy.scrollTo("commentInputField", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: isTextFieldFocused) {
                // Report keyboard state to parent
                onKeyboardActive(isTextFieldFocused)
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            MultiImagePicker(images: $selectedImages, selectionLimit: 5)
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                keyboardHeight = keyboardFrame.height - 10 // Provide much more space to clear keyboard suggestions
                onKeyboardActive(true)
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
                onKeyboardActive(false)
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
            onKeyboardActive(false)
        }
    }
     
    private func loadMoreComments() {
        // Increase the limit and reload comments
        loadedCommentLimit += 5
        
        guard let placeId = selectedPlaceVM.selectedPlace?.id.uuidString else { return }
        selectedPlaceVM.loadMoreComments(placeId: placeId, reviewId: reviewId, limit: loadedCommentLimit)
    }
    
    private func submitComment() {
        // Allow submission if either text or images are present
        guard !commentText.isEmpty || !selectedImages.isEmpty else { return }
        
        selectedPlaceVM.addComment(
            reviewId: reviewId,
            text: commentText,
            images: selectedImages,
            userId: userSession.currentUserId ?? "unknown",
            userFirstName: profile.user?.firstName ?? "unknown",
            userLastName: profile.user?.lastName ?? "unknown",
            profilePhotoUrl: profile.user?.profilePhotoURL?.absoluteString ?? ""
        )
        
        // Clear form
        commentText = ""
        selectedImages = []
    }
}
