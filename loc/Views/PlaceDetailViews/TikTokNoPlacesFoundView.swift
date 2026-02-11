//
//  TikTokNoPlacesFoundView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct TikTokNoPlacesFoundView: View {
    let tikTokUrl: String
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode

    /// Convenience accessor for TikTok view model.
    private var tikTokVM: ProfileTikTokViewModel { profile.tikTokViewModel }

    @State private var userComment: String = ""
    @State private var showingCommentDialog = false
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingCorrectionSheet = false

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator
            Spacer().frame(height: 32)
            headerSection
            Spacer().frame(height: 28)
            actionButtons
            Spacer()
        }
        .onAppear {
            tikTokVM.isProcessingTikTok = false
            tikTokVM.isWaitingForPlaceDetail = false
        }
        .alert("Help Improve Detection", isPresented: $showingCommentDialog) {
            TextField("Describe the place that should have been detected...", text: $userComment, axis: .vertical)
                .lineLimit(3...6)
            Button("Cancel", role: .cancel) {
                userComment = ""
            }
            Button("Submit Flag") {
                let success = tikTokVM.submitNoPlacesFoundFlag(tikTokUrl: tikTokUrl, userComment: userComment)
                if success {
                    isSubmitting = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isSubmitting = false
                        userComment = ""
                        showingSuccessAlert = true
                    }
                } else {
                    errorMessage = "You must be logged in to submit flags"
                    showingErrorAlert = true
                }
            }
            .disabled(isSubmitting)
        } message: {
            Text("Help us understand what place should have been detected from this TikTok video.")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") {
                profile.clearNoPlacesFound()
            }
        } message: {
            Text("Operation completed successfully!")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingCorrectionSheet) {
            TikTokPlaceCorrectionSheet(
                mode: .newAssignment(tikTokUrl: tikTokUrl),
                onPlaceChanged: { _ in
                    profile.clearNoPlacesFound()
                }
            )
            .environmentObject(profile)
        }
    }

    /// Displays a subtle drag indicator at the top of the sheet.
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
    }

    /// Displays the header with icon and description text.
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                Text("No Place Found")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("We couldn't identify a place in this TikTok")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Displays the action buttons for finding a place or flagging.
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: {
                showingCorrectionSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                    Text("Find Place")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button(action: {
                showingCommentDialog = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "flag")
                        .font(.system(size: 15, weight: .medium))
                    Text("Flag for Review")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            Button(action: {
                profile.clearNoPlacesFound()
            }) {
                Text("Dismiss")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }
}
