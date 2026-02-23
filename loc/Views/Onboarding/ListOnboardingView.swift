//
//  ListOnboardingView.swift
//  loc
//
//  Fullscreen onboarding: import saved places from a Google Maps list, or skip.
//

import SwiftUI

struct ListOnboardingView: View {
    @StateObject private var viewModel = ListOnboardingViewModel()
    @EnvironmentObject var userSession: UserSession

    @State private var showContent = false

    // MARK: - Brand Colors (matching LoginView / ProfilePhotoOnboardingView)
    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)
    private let cardBackground = Color(red: 248/255, green: 248/255, blue: 250/255)
    private let subtleGray = Color(red: 200/255, green: 200/255, blue: 205/255)

    /// Shorthand reference to the import child ViewModel.
    private var importVM: GoogleMapsImportViewModel {
        viewModel.importViewModel
    }

    var body: some View {
        Group {
            currentScreen
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: importVM.importState)
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasResults)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                showContent = true
            }
        }
    }

    // MARK: - Screen Router

    /// Routes to the appropriate screen based on the current import state.
    @ViewBuilder
    private var currentScreen: some View {
        switch importVM.importState {
        case .idle:
            if viewModel.hasResults {
                previewScreen
            } else {
                urlEntryScreen
            }
        case .extracting:
            extractingScreen
        case .resolvingPlaces(let current, let total):
            resolvingScreen(current: current, total: total)
        case .creatingList:
            creatingScreen(subtitle: "Creating your list...")
        case .addingPlaces(let current, let total):
            creatingScreen(subtitle: "Adding place \(current) of \(total)...")
        case .completed:
            completeScreen
        case .failed(let message):
            failedScreen(message: message)
        }
    }

    // MARK: - URL Entry Screen

    /// Landing screen with instructions, URL paste field, import button, and skip.
    private var urlEntryScreen: some View {
        VStack(alignment: .leading, spacing: 20) {
            titleSection(
                title: "Import your saved places",
                subtitle: "Bring your Google Maps lists into Mesa\nand start sharing with friends."
            )

            instructionsCard

            urlTextField

            importButton

            Spacer()

            skipButton
        }
        .padding(.horizontal, 28)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    /// Numbered steps card explaining how to share a Google Maps list.
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            instructionRow(number: "1", text: "Open Google Maps")
            instructionRow(number: "2", text: "Go to Saved → Your List")
            instructionRow(number: "3", text: "Tap Share → Copy Link")
            instructionRow(number: "4", text: "Paste the link below")
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    /// Renders a single numbered instruction step.
    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(mesaCharcoal))

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }

    /// Text field for pasting a Google Maps list URL.
    private var urlTextField: some View {
        TextField("Paste Google Maps list link...", text: $viewModel.importViewModel.url)
            .font(.system(size: 16))
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(subtleGray.opacity(0.5), lineWidth: 1)
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }

    /// Capsule button that triggers the import flow.
    private var importButton: some View {
        Button {
            Task { await viewModel.startImport() }
        } label: {
            Text("Import")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule().fill(viewModel.canExtract ? mesaCharcoal : mesaCharcoal.opacity(0.4))
                )
        }
        .disabled(!viewModel.canExtract)
    }

    /// Text button that skips list onboarding entirely.
    private var skipButton: some View {
        HStack {
            Spacer()
            Button {
                userSession.completeListOnboarding()
            } label: {
                Text("Skip for now")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }

    // MARK: - Extracting Screen

    /// Spinner screen shown while extracting place names from the URL.
    private var extractingScreen: some View {
        progressScreen(
            title: "Extracting places...",
            subtitle: "Reading your Google Maps list"
        )
    }

    // MARK: - Resolving Screen

    /// Spinner screen with progress bar shown while resolving each place.
    private func resolvingScreen(current: Int, total: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.3)

            VStack(spacing: 8) {
                Text("Resolving places...")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(mesaCharcoal)

                Text("Matching place \(current) of \(total)")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }

            ProgressView(value: Double(current), total: Double(total))
                .tint(mesaCharcoal)
                .padding(.horizontal, 60)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Preview Screen

    /// Shows resolved places for review before creating the list.
    private var previewScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            previewHeader

            listNameField

            resolvedPlacesList

            unresolvedErrors

            createListButton

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 60)
    }

    /// Header showing total resolved places and any unresolved count.
    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(importVM.resolvedPlaces.count) places found")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(mesaCharcoal)

            if !importVM.resolveErrors.isEmpty {
                Text("\(importVM.resolveErrors.count) could not be resolved")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }
        }
    }

    /// Editable text field for the list name, auto-populated from Google Maps.
    private var listNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("List name")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)

            TextField("Enter list name", text: $viewModel.importViewModel.listName)
                .font(.system(size: 17))
                .padding(14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(subtleGray.opacity(0.5), lineWidth: 1)
                )
        }
    }

    /// Scrollable list of resolved places with name and address.
    private var resolvedPlacesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(importVM.resolvedPlaces) { place in
                    placeRow(place)
                }
            }
        }
        .frame(maxHeight: 280)
    }

    /// Renders a single resolved place row with map pin icon, name, and address.
    private func placeRow(_ place: ImportedPlace) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(mesaCharcoal.opacity(0.6))

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(place.address)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    /// Displays any unresolved place errors in orange text.
    @ViewBuilder
    private var unresolvedErrors: some View {
        if !importVM.resolveErrors.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(importVM.resolveErrors, id: \.self) { error in
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
        }
    }

    /// Capsule button that creates a new list with all resolved places.
    private var createListButton: some View {
        Button {
            guard let userId = userSession.currentUserId else { return }
            Task { await viewModel.createList(userId: userId) }
        } label: {
            Text("Create List")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule().fill(viewModel.canCreateList ? mesaCharcoal : mesaCharcoal.opacity(0.4))
                )
        }
        .disabled(!viewModel.canCreateList)
    }

    // MARK: - Creating Screen

    /// Spinner screen shown while creating the list and adding places.
    private func creatingScreen(subtitle: String) -> some View {
        progressScreen(
            title: "Setting up your list...",
            subtitle: subtitle
        )
    }

    // MARK: - Complete Screen

    /// Success screen with checkmark, place count summary, and continue button.
    private var completeScreen: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(mesaCharcoal)

                Text("\(importVM.resolvedPlaces.count) places added to '\(importVM.listName)'")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            Button {
                userSession.completeListOnboarding()
            } label: {
                Text("Continue")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(mesaCharcoal))
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Failed Screen

    /// Error screen with warning icon, error message, try-again and skip options.
    private func failedScreen(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Import failed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(mesaCharcoal)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button {
                viewModel.reset()
            } label: {
                Text("Try Again")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(mesaCharcoal))
            }

            skipButton

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Shared Components

    /// Renders a title and subtitle pair in the standard onboarding style.
    private func titleSection(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(mesaCharcoal)

            Text(subtitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .lineSpacing(2)
        }
    }

    /// Renders a centered spinner with title and subtitle text.
    private func progressScreen(title: String, subtitle: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.3)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(mesaCharcoal)

                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
