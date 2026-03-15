//
//  ProfilePhotoOnboardingView.swift
//  loc
//
//  Fullscreen onboarding step requiring a profile photo before entering the app.
//

import SwiftUI

struct ProfilePhotoOnboardingView: View {
    @StateObject var viewModel: ProfilePhotoOnboardingViewModel
    @EnvironmentObject var userSession: UserSession

    @State private var showSheet = false

    // MARK: - Brand Colors (matching LoginView)
    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)
    private let cardBackground = Color(red: 248/255, green: 248/255, blue: 250/255)
    private let subtleGray = Color(red: 200/255, green: 200/255, blue: 205/255)

    init(userId: String) {
        self._viewModel = StateObject(wrappedValue: ProfilePhotoOnboardingViewModel(userId: userId))
    }

    var body: some View {
        ZStack {
            mesaCharcoal.ignoresSafeArea()

            Image("LoginImage")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()
                bottomCard
                    .offset(y: showSheet ? 0 : 500)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                showSheet = true
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePicker(images: $viewModel.pickerImages, selectionLimit: 1)
        }
        .onChange(of: viewModel.isOnboardingComplete) { _, isComplete in
            if isComplete {
                userSession.completeProfilePhotoOnboarding()
            }
        }
    }

    // MARK: - Bottom Card

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            dragIndicator
            titleSection
            photoSection
            buttonsSection
            errorSection
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 50)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(cardBackground)
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: -10)
        )
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(subtleGray)
                .frame(width: 40, height: 5)
            Spacer()
        }
        .padding(.bottom, 8)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a Profile Photo")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(mesaCharcoal)

            Text("Help your friends recognize you.\nYou can always change it later.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .lineSpacing(2)
        }
    }

    // MARK: - Photo Preview

    private var photoSection: some View {
        HStack {
            Spacer()
            photoPreview
            Spacer()
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let image = viewModel.selectedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(subtleGray.opacity(0.4), lineWidth: 1))
        } else {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(subtleGray)
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundColor(subtleGray)
                )
        }
    }

    // MARK: - Buttons Section

    private var buttonsSection: some View {
        VStack(spacing: 12) {
            choosePhotoButton
            continueButton
        }
    }

    private var choosePhotoButton: some View {
        Button {
            viewModel.showImagePicker = true
        } label: {
            Text(viewModel.selectedImage != nil ? "Change Photo" : "Choose Photo")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(mesaCharcoal)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                )
                .overlay(Capsule().stroke(subtleGray.opacity(0.5), lineWidth: 1))
        }
    }

    private var continueButton: some View {
        Button {
            viewModel.handleContinue()
        } label: {
            Group {
                if viewModel.isUploading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(.system(size: 19, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule().fill(viewModel.canContinue ? mesaCharcoal : mesaCharcoal.opacity(0.4))
            )
        }
        .disabled(!viewModel.canContinue || viewModel.isUploading)
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.top, 4)
        }
    }
}
