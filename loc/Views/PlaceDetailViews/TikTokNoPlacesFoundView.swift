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
    @EnvironmentObject var userSession: UserSession
    @Environment(\.presentationMode) var presentationMode
    
    @State private var userComment: String = ""
    @State private var showingCommentDialog = false
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon and message
            VStack(spacing: 16) {
                Image(systemName: "map.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("No Places Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("We couldn't identify any specific places in this TikTok video")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            // Help improve section
            VStack(spacing: 12) {
                Text("Help us improve place detection")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("If this video should have shown a specific place, let us know so we can improve our detection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button(action: {
                    showingCommentDialog = true
                }) {
                    HStack {
                        Image(systemName: "flag")
                            .font(.system(size: 16))
                        Text("Flag as Unable to Identify")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Close button
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 30)
        .alert("Help Improve Detection", isPresented: $showingCommentDialog) {
            TextField("Describe the place that should have been detected...", text: $userComment, axis: .vertical)
                .lineLimit(3...6)
            Button("Cancel", role: .cancel) {
                userComment = ""
            }
            Button("Submit Flag") {
                submitFlag()
            }
            .disabled(isSubmitting)
        } message: {
            Text("Help us understand what place should have been detected from this TikTok video.")
        }
        .alert("Flag Submitted", isPresented: $showingSuccessAlert) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Thank you for helping us improve! Your feedback has been recorded.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func submitFlag() {
        guard let userId = userSession.currentUserId else {
            errorMessage = "You must be logged in to submit flags"
            showingErrorAlert = true
            return
        }
        
        isSubmitting = true
        
        // Create a temporary place ID for this flag since no place was found
        let tempPlaceId = "no_place_found_\(UUID().uuidString)"
        
        profile.flagTikTokPlace(
            for: tempPlaceId,
            flagType: .unableToIdentify,
            tikTokUrl: tikTokUrl,
            userComment: userComment.isEmpty ? nil : userComment
        )
        
        // Simulate delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            userComment = ""
            showingSuccessAlert = true
        }
    }
}
