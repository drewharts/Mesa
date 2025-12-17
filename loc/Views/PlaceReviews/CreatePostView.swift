//
//  CreatePostView.swift
//  loc
//
//  Simplified post creation as a sheet - share photos and/or text with optional sentiment
//

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlace: SelectedPlaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let place: DetailPlace

    @StateObject private var viewModel: PlacePostViewModel
    
    // Image picker states
    @State private var showingImagePicker = false
    @State private var inputImages: [UIImage] = []
    
    // Optional sections visibility
    @State private var showTextSection = false
    @State private var showSentimentSection = false
    
    let onPostSubmitted: ((DetailPlace) -> Void)?
    
    // Match sheet corner radius
    private let cornerRadius: CGFloat = 16
    
    init(isPresented: Binding<Bool>, place: DetailPlace, userId: String, profilePhotoUrl: String, userFirstName: String, userLastName: String, preselectedImages: [UIImage] = [], onPostSubmitted: ((DetailPlace) -> Void)? = nil) {
        self._isPresented = isPresented
        self.place = place
        self.onPostSubmitted = onPostSubmitted

        _viewModel = StateObject(
            wrappedValue: PlacePostViewModel(
                place: place,
                userId: userId,
                userFirstName: userFirstName,
                userLastName: userLastName,
                profilePhotoUrl: profilePhotoUrl
            )
        )
        
        self._inputImages = State(initialValue: preselectedImages)
    }
    
    private var canSubmit: Bool {
        !inputImages.isEmpty || !viewModel.postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Photo section (primary action)
                    photoSection
                    
                    // Optional sections with + buttons
                    optionalSectionsArea
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        isPresented = false
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
                        .disabled(!canSubmit)
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
            MultiImagePicker(images: $inputImages, selectionLimit: 0)
        }
        .onAppear {
            // Show sections if there's existing content
            showTextSection = !viewModel.postText.isEmpty
            showSentimentSection = viewModel.wouldReturn != nil
        }
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected images preview
            if !inputImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(inputImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                // Remove button
                                Button(action: {
                                    inputImages.remove(at: index)
                                }) {
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
                        
                        // Add more photos button (inline with images)
                        addPhotoButton
                    }
                }
            } else {
                // Large add photos button when empty
                addPhotoButton
            }
        }
    }
    
    private var addPhotoButton: some View {
        Button(action: { showingImagePicker = true }) {
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                if inputImages.isEmpty {
                    Text("Add Photos")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.gray)
            .frame(width: inputImages.isEmpty ? nil : 100, height: 100)
            .frame(maxWidth: inputImages.isEmpty ? .infinity : nil)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
    
    // MARK: - Optional Sections Area
    
    private var optionalSectionsArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Text section (expandable)
            if showTextSection || !viewModel.postText.isEmpty {
                textSection
            }
            
            // Sentiment section (expandable)
            if showSentimentSection || viewModel.wouldReturn != nil {
                sentimentSection
            }
            
            // Add buttons row for collapsed sections
            addButtonsRow
        }
    }
    
    @ViewBuilder
    private var addButtonsRow: some View {
        let showCaptionButton = !showTextSection && viewModel.postText.isEmpty
        let showSentimentButton = !showSentimentSection && viewModel.wouldReturn == nil
        
        if showCaptionButton || showSentimentButton {
            HStack(spacing: 12) {
                if showCaptionButton {
                    addOptionButton(title: "Caption", icon: "text.bubble") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showTextSection = true
                        }
                    }
                }
                
                if showSentimentButton {
                    addOptionButton(title: "Would Return?", icon: "hand.thumbsup") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSentimentSection = true
                        }
                    }
                }
            }
        }
    }
    
    private func addOptionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
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
    
    // MARK: - Text Section
    
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Caption")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.postText = ""
                        showTextSection = false
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
    
    // MARK: - Sentiment Section
    
    private var sentimentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Would you go back?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.wouldReturn = nil
                        showSentimentSection = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
            }
            
            HStack(spacing: 12) {
                sentimentButton(
                    title: "Yes",
                    icon: "hand.thumbsup.fill",
                    isSelected: viewModel.wouldReturn == true,
                    color: .green
                ) {
                    viewModel.wouldReturn = viewModel.wouldReturn == true ? nil : true
                }
                
                sentimentButton(
                    title: "No",
                    icon: "hand.thumbsdown.fill",
                    isSelected: viewModel.wouldReturn == false,
                    color: .red
                ) {
                    viewModel.wouldReturn = viewModel.wouldReturn == false ? nil : false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func sentimentButton(title: String, icon: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
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
    
    // MARK: - Submit
    
    private func submitPost() {
        viewModel.images = inputImages
        
        viewModel.submitPost { result in
            switch result {
            case .success(let savedPost):
                selectedPlace.addPost(savedPost)
                dismiss()
                isPresented = false
                onPostSubmitted?(place)
                
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
