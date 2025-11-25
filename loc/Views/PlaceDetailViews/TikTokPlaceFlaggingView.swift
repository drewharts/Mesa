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
                // Compact Header
                HStack {
                    Image(systemName: hasExistingFlag ? "flag.fill" : "flag")
                        .foregroundColor(.yellow)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(hasExistingFlag ? "Place Flagged" : "Help Improve Detection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if hasExistingFlag {
                        Button(action: {
                            removeFlag()
                        }) {
                            Text("Remove")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {
                            showingFlagDialog = true
                        }) {
                            Text("Flag")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if hasExistingFlag {
                    // Show existing flag details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(existingFlag?.flagType.displayName ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let comment = existingFlag?.userComment, !comment.isEmpty {
                            Text(comment)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .onAppear {
                profile.loadTikTokPlaceFlag(for: place.id.uuidString)
            }
            .actionSheet(isPresented: $showingFlagDialog) {
                ActionSheet(
                    title: Text("Flag Place"),
                    message: Text("Help us improve place detection"),
                    buttons: [
                        .default(Text("Unable to identify place")) {
                            selectedFlagType = .unableToIdentify
                            showingCommentDialog = true
                        },
                        .default(Text("Wrong suggestion")) {
                            selectedFlagType = .wrongSuggestion
                            showingCommentDialog = true
                        },
                        .cancel()
                    ]
                )
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
        let tikTokUrl = profile.getExternalPlace(for: place.id.uuidString)?.url
        
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
