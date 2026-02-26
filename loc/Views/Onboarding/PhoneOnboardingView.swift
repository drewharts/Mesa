//
//  PhoneOnboardingView.swift
//  loc
//
//  Fullscreen onboarding step collecting the user's phone number.
//  Matches the card-from-bottom design of ProfilePhotoOnboardingView.
//

import SwiftUI

struct PhoneOnboardingView: View {
    @StateObject var viewModel: PhoneOnboardingViewModel
    @EnvironmentObject var userSession: UserSession

    @State private var showSheet = false

    // MARK: - Brand Colors (matching LoginView / ProfilePhotoOnboardingView)
    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)
    private let cardBackground = Color(red: 248/255, green: 248/255, blue: 250/255)
    private let subtleGray = Color(red: 200/255, green: 200/255, blue: 205/255)

    init(userId: String) {
        self._viewModel = StateObject(wrappedValue: PhoneOnboardingViewModel(userId: userId))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            bottomCard
                .offset(y: showSheet ? 0 : 500)
        }
        .background {
            ZStack {
                mesaCharcoal
                Image("LoginImage")
                    .resizable()
                    .scaledToFill()
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                showSheet = true
            }
        }
        .onChange(of: viewModel.isOnboardingComplete) { _, isComplete in
            if isComplete {
                userSession.completePhoneOnboarding()
            }
        }
    }

    // MARK: - Bottom Card

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            dragIndicator
            titleSection
            phoneInputSection
            buttonsSection
            errorSection
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(cardBackground)
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: -10)
            .frame(height: 800)
        }
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
            Text("Add Your Phone Number")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(mesaCharcoal)

            Text("Help friends find you on Mesa.\nWe'll never share your number.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .lineSpacing(2)
        }
    }

    // MARK: - Phone Input Section

    private var phoneInputSection: some View {
        HStack(spacing: 12) {
            countryCodePicker
            phoneTextField
        }
    }

    private var countryCodePicker: some View {
        Menu {
            ForEach(CountryCode.common) { country in
                Button {
                    viewModel.selectedCountryCode = country
                } label: {
                    Text("\(country.flag) \(country.name) (\(country.dialCode))")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedCountryCode.flag)
                    .font(.system(size: 20))
                Text(viewModel.selectedCountryCode.dialCode)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(mesaCharcoal)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(subtleGray.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var phoneTextField: some View {
        TextField("Phone number", text: $viewModel.phoneInput)
            .keyboardType(.phonePad)
            .font(.system(size: 18, weight: .regular))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(subtleGray.opacity(0.5), lineWidth: 1)
            )
    }

    // MARK: - Buttons Section

    private var buttonsSection: some View {
        continueButton
    }

    private var continueButton: some View {
        Button {
            Task {
                await viewModel.submitPhoneNumber()
            }
        } label: {
            Group {
                if viewModel.isSubmitting {
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
                Capsule().fill(viewModel.isValidNumber ? mesaCharcoal : mesaCharcoal.opacity(0.4))
            )
        }
        .disabled(!viewModel.isValidNumber || viewModel.isSubmitting)
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
