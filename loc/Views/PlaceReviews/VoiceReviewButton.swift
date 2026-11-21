//
//  VoiceReviewButton.swift
//  loc
//
//  Mic button + live transcript for dictating a review instead of typing it
//

import SwiftUI

struct VoiceReviewButton: View {
    @ObservedObject var viewModel: VoiceReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            micRow

            if viewModel.phase == .recording {
                Text(viewModel.liveTranscript.isEmpty ? "Listening… tell us about your visit" : viewModel.liveTranscript)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.permissionDenied { deniedMessage }

            if let error = viewModel.errorMessage {
                Text(error).font(.footnote).foregroundColor(.red)
            }

            if viewModel.phase == .idle && viewModel.canUndo { resultActions }
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.phase)
        .onDisappear { viewModel.cancel() }
    }

    private var micRow: some View {
        Button(action: { viewModel.toggle() }) {
            HStack(spacing: 10) {
                micIcon
                Text(micTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if viewModel.phase == .recording {
                    Text(viewModel.elapsedLabel)
                        .font(.subheadline.monospacedDigit())
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(viewModel.phase == .recording ? Color.red : Color.accentColor)
            .clipShape(Capsule())
        }
        .disabled(viewModel.phase == .summarizing)
    }

    @ViewBuilder
    private var micIcon: some View {
        if viewModel.phase == .summarizing {
            ProgressView().tint(.white)
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .scaleEffect(1 + CGFloat(viewModel.level) * 0.6)
                    .animation(.easeOut(duration: 0.1), value: viewModel.level)
                Image(systemName: viewModel.phase == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(width: 34, height: 34)
        }
    }

    private var micTitle: String {
        switch viewModel.phase {
        case .idle: return "Tap and just talk"
        case .recording: return "Tap to finish"
        case .summarizing: return "Summarizing…"
        }
    }

    private var deniedMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mesa needs microphone and speech recognition access to turn your voice into a review.")
                .font(.footnote)
                .foregroundColor(.secondary)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private var resultActions: some View {
        HStack(spacing: 16) {
            if viewModel.canToggleTranscript {
                Button(viewModel.usingFullTranscript ? "Use summary" : "Use full transcript") {
                    viewModel.toggleFullTranscript()
                }
            }
            Button("Undo") { viewModel.undo() }
        }
        .font(.footnote.weight(.semibold))
    }
}
