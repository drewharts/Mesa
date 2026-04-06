//
//  FeedbackSheet.swift
//  loc
//
//  Sheet for submitting feedback directly to the Mesa creator.
//

import SwiftUI

/// Sheet that lets users send feedback directly to the Mesa creator.
struct FeedbackSheet: View {
    let userId: String

    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var showThankYou = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                textEditor
                Spacer()
            }
            .padding()
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    submitButton
                }
            }
            .alert("Thank You!", isPresented: $showThankYou) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thanks for taking the time! I'll read this personally and get back to you soon.")
            }
        }
    }

    /// Personal message from the creator encouraging honest feedback.
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("This goes directly to Drew, the creator of Mesa.")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            Text("All feedback is immensely helpful — no matter how critical. I'll respond ASAP.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    /// Text editor for the feedback message.
    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $feedbackText)
                .frame(minHeight: 150)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            if feedbackText.isEmpty {
                Text("What's on your mind?")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Submit button that sends feedback to the database.
    private var submitButton: some View {
        Button {
            Task { await submitFeedback() }
        } label: {
            if isSubmitting {
                ProgressView()
            } else {
                Text("Send")
                    .fontWeight(.semibold)
            }
        }
        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
    }

    /// Submits the feedback to the user_feedback table.
    private func submitFeedback() async {
        isSubmitting = true
        do {
            try await SupabaseManager.shared.client
                .from("user_feedback")
                .insert([
                    "user_id": userId,
                    "message": feedbackText.trimmingCharacters(in: .whitespacesAndNewlines),
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                ])
                .execute()
            showThankYou = true
        } catch {
            print("❌ [FeedbackSheet] Failed to submit feedback: \(error)")
        }
        isSubmitting = false
    }
}
