//
//  TikTokPlaceFlaggingView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct TikTokPlaceFlaggingView: View {
    let place: DetailPlace
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedFlagType: TikTokPlaceFlagType?
    @State private var userComment: String = ""
    @State private var showingFlagDialog = false
    @State private var showingCommentDialog = false
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    private var isTikTokPlace: Bool {
        return profile.hasTikTokVideos(for: place.id.uuidString)
    }
    
    private var hasExistingFlag: Bool {
        return profile.hasFlaggedTikTokPlace(placeId: place.id.uuidString)
    }
    
    private var existingFlag: TikTokPlaceFlag? {
        return profile.getTikTokPlaceFlag(for: place.id.uuidString)
    }
    
    var body: some View {
        if isTikTokPlace {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "flag")
                        .foregroundColor(.orange)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("Help Improve Place Detection")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if hasExistingFlag {
                        Button(action: {
                            removeFlag()
                        }) {
                            Image(systemName: "flag.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                if hasExistingFlag {
                    // Show existing flag
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("Flagged: \(existingFlag?.flagType.displayName ?? "")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        
                        if let comment = existingFlag?.userComment, !comment.isEmpty {
                            Text("Comment: \(comment)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                } else {
                    // Show flagging options
                    VStack(spacing: 12) {
                        // Unable to identify button
                        Button(action: {
                            selectedFlagType = .unableToIdentify
                            showingFlagDialog = true
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.blue)
                                Text("Unable to identify place")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Wrong suggestion button
                        Button(action: {
                            selectedFlagType = .wrongSuggestion
                            showingFlagDialog = true
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Wrong suggestion")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("Help us improve by flagging incorrect place suggestions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .onAppear {
                profile.loadTikTokPlaceFlag(for: place.id.uuidString)
            }
            .alert("Flag Place", isPresented: $showingFlagDialog) {
                Button("Cancel", role: .cancel) { }
                Button("Continue") {
                    showingCommentDialog = true
                }
            } message: {
                if let flagType = selectedFlagType {
                    Text(flagType.description)
                }
            }
            .alert("Add Comment (Optional)", isPresented: $showingCommentDialog) {
                TextField("Additional details...", text: $userComment)
                Button("Cancel", role: .cancel) {
                    userComment = ""
                }
                Button("Submit Flag") {
                    submitFlag()
                }
                .disabled(isSubmitting)
            } message: {
                Text("Help us understand the issue better by providing additional details.")
            }
            .alert("Flag Submitted", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Thank you for helping us improve! Your feedback has been recorded.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitFlag() {
        guard let flagType = selectedFlagType else { return }
        
        isSubmitting = true
        
        // Get TikTok URL if available
        let tikTokUrl = profile.getExternalPlace(for: place.id.uuidString)?.tiktokVideos.first?.url
        
        profile.flagTikTokPlace(
            for: place.id.uuidString,
            flagType: flagType,
            tikTokUrl: tikTokUrl,
            userComment: userComment.isEmpty ? nil : userComment
        )
        
        // Simulate delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            userComment = ""
            selectedFlagType = nil
            showingSuccessAlert = true
        }
    }
    
    private func removeFlag() {
        profile.removeTikTokPlaceFlag(for: place.id.uuidString)
    }
}
