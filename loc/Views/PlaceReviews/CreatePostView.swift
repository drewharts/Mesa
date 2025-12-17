//
//  CreatePostView.swift
//  loc
//
//  Simplified post creation as a sheet - share photos and/or text with optional sentiment
//

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @EnvironmentObject var selectedPlace: SelectedPlaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: PlacePostViewModel
    
    @State private var showingImagePicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let onPostSubmitted: ((DetailPlace) -> Void)?
    
    // MARK: - Init
    
    init(place: DetailPlace,
         userId: String,
         profilePhotoUrl: String,
         userFirstName: String,
         userLastName: String,
         preselectedImages: [UIImage] = [],
         onPostSubmitted: ((DetailPlace) -> Void)? = nil) {
        
        self.onPostSubmitted = onPostSubmitted
        
        _viewModel = StateObject(
            wrappedValue: PlacePostViewModel(
                place: place,
                userId: userId,
                userFirstName: userFirstName,
                userLastName: userLastName,
                profilePhotoUrl: profilePhotoUrl,
                preselectedImages: preselectedImages
            )
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PostPhotoSection(viewModel: viewModel, showingImagePicker: $showingImagePicker)
                    PostOptionalSections(viewModel: viewModel)
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
            .navigationTitle(viewModel.place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Share") {
                            submitPost()
                        }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.canSubmit)
                    }
                }
            }
            .alert("Post Failed", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            MultiImagePicker(images: Binding(
                get: { viewModel.images },
                set: { viewModel.images = $0 }
            ), selectionLimit: 0)
        }
    }
    
    // MARK: - Actions
    
    private func submitPost() {
        viewModel.submitPost { result in
            switch result {
            case .success(let savedPost):
                selectedPlace.addPost(savedPost)
                dismiss()
                onPostSubmitted?(viewModel.place)
                
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

// MARK: - Photo Section

private struct PostPhotoSection: View {
    @ObservedObject var viewModel: PlacePostViewModel
    @Binding var showingImagePicker: Bool
    
    private let cornerRadius: CGFloat = 16
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(viewModel.images.enumerated()), id: \.offset) { index, image in
                            imageCell(image: image, index: index)
                        }
                        addPhotoButton(compact: true)
                    }
                }
            } else {
                addPhotoButton(compact: false)
            }
        }
    }
    
    private func imageCell(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Button(action: { viewModel.removeImage(at: index) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .offset(x: 8, y: -8)
        }
        .padding(.top, 10)
        .padding(.trailing, 10)
    }
    
    private func addPhotoButton(compact: Bool) -> some View {
        Button(action: { showingImagePicker = true }) {
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                if !compact {
                    Text("Add Photos")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.gray)
            .frame(width: compact ? 100 : nil, height: 100)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Optional Sections

private struct PostOptionalSections: View {
    @ObservedObject var viewModel: PlacePostViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.showCaptionSection || !viewModel.postText.isEmpty {
                PostCaptionSection(viewModel: viewModel)
            }
            
            if viewModel.showSentimentSection || viewModel.wouldReturn != nil {
                PostSentimentSection(viewModel: viewModel)
            }
            
            addButtonsRow
        }
    }
    
    @ViewBuilder
    private var addButtonsRow: some View {
        if viewModel.shouldShowCaptionButton || viewModel.shouldShowSentimentButton {
            HStack(spacing: 12) {
                if viewModel.shouldShowCaptionButton {
                    AddOptionButton(title: "Caption", icon: "text.bubble") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showCaption()
                        }
                    }
                }
                
                if viewModel.shouldShowSentimentButton {
                    AddOptionButton(title: "Would Return?", icon: "hand.thumbsup") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showSentiment()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Caption Section

private struct PostCaptionSection: View {
    @ObservedObject var viewModel: PlacePostViewModel
    
    private let cornerRadius: CGFloat = 16
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Caption")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.hideCaption()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.postText)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                if viewModel.postText.isEmpty {
                    Text("What was your experience like?")
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Sentiment Section

private struct PostSentimentSection: View {
    @ObservedObject var viewModel: PlacePostViewModel
    
    private let cornerRadius: CGFloat = 16
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Would you go back?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.hideSentiment()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
            }
            
            HStack(spacing: 12) {
                SentimentButton(
                    title: "Yes",
                    icon: "hand.thumbsup.fill",
                    isSelected: viewModel.wouldReturn == true,
                    color: .green,
                    cornerRadius: cornerRadius
                ) {
                    viewModel.toggleWouldReturn(true)
                }
                
                SentimentButton(
                    title: "No",
                    icon: "hand.thumbsdown.fill",
                    isSelected: viewModel.wouldReturn == false,
                    color: .red,
                    cornerRadius: cornerRadius
                ) {
                    viewModel.toggleWouldReturn(false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Reusable Components

private struct AddOptionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.gray)
        }
    }
}

private struct SentimentButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let cornerRadius: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? color : color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
