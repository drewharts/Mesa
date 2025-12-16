//
//  CreatePostView.swift
//  loc
//
//  Simplified post creation - share photos and/or text with optional sentiment
//

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlace: SelectedPlaceViewModel
    @State private var showButtonHighlight = false
    @State private var showAlert = false
    @State private var showSuccessAlert = false
    @State private var alertMessage = ""
    
    let place: DetailPlace

    @StateObject private var viewModel: PlacePostViewModel
    
    // Image picker states
    @State private var showingImagePicker = false
    @State private var inputImages: [UIImage] = []
    
    let onPostSubmitted: ((DetailPlace) -> Void)?
    
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
    
    private var btnBack: some View {
        Button(action: {
            guard !viewModel.isLoading else { return }
            isPresented = false
        }) {
            HStack {
                Image(systemName: "chevron.left")
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.black)
            }
        }
        .disabled(viewModel.isLoading)
    }
    
    private var canSubmit: Bool {
        !inputImages.isEmpty || !viewModel.postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Photo upload section
                    photoSection
                    
                    // Text input section
                    textSection
                    
                    // Sentiment selection (optional)
                    sentimentSection
                    
                    // Submit button
                    submitButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
            .background(Color.white)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
        .sheet(isPresented: $showingImagePicker) {
            MultiImagePicker(images: $inputImages, selectionLimit: 0)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(place.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            Text("Share your experience")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Upload button
            Button(action: { showingImagePicker = true }) {
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.body)
                    Text(inputImages.isEmpty ? "Add Photos" : "Add More Photos")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            }
            
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
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                
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
                            .padding(.top, 10) // Room for X button above image
                            .padding(.trailing, 10) // Room for X button on right
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Text Section
    
    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.postText)
                    .font(.body)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundStyle(.black)

                if viewModel.postText.isEmpty {
                    Text("What was your experience like?")
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - Sentiment Section
    
    private var sentimentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Would you go back?")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                // Would go back button
                sentimentButton(
                    title: "Would go back",
                    icon: "hand.thumbsup.fill",
                    isSelected: viewModel.wouldReturn == true,
                    color: .green
                ) {
                    if viewModel.wouldReturn == true {
                        viewModel.wouldReturn = nil
                    } else {
                        viewModel.wouldReturn = true
                    }
                }
                
                // Wouldn't revisit button
                sentimentButton(
                    title: "Wouldn't revisit",
                    icon: "hand.thumbsdown.fill",
                    isSelected: viewModel.wouldReturn == false,
                    color: .red
                ) {
                    if viewModel.wouldReturn == false {
                        viewModel.wouldReturn = nil
                    } else {
                        viewModel.wouldReturn = false
                    }
                }
            }
            
            Text("Optional - tap to select or deselect")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func sentimentButton(title: String, icon: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? color : color.opacity(0.1))
            .cornerRadius(20)
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button(action: submitPost) {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(25)
            } else {
                Text("Share Post")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSubmit ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(canSubmit ? .white : .gray)
                    .cornerRadius(25)
            }
        }
        .disabled(!canSubmit || viewModel.isLoading)
        .padding(.top, 8)
        .alert("Post Failed", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("Posted!", isPresented: $showSuccessAlert) {
            Button("OK") {
                isPresented = false
                onPostSubmitted?(place)
            }
        } message: {
            Text("Your post has been shared!")
        }
    }
    
    private func submitPost() {
        viewModel.images = inputImages
        
        viewModel.submitPost { result in
            switch result {
            case .success(let savedPost):
                selectedPlace.addPost(savedPost)
                showSuccessAlert = true
                
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

