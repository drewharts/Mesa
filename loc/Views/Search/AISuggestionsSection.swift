//
//  AISuggestionsSection.swift
//  loc
//
//  DUMB Component: Displays AI suggestions section
//

import SwiftUI

/// DUMB Component: Displays the AI suggestions section with header and results
/// Single Responsibility: Render AI suggestions list with loading state
struct AISuggestionsSection: View {
    let suggestions: [DetailPlace]
    let isLoading: Bool
    let error: String?
    @Binding var isCollapsed: Bool
    let onSelectPlace: (DetailPlace) -> Void

    var body: some View {
        if isLoading || !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                contentView
            }
        }
    }

    // MARK: - Subviews

    /// Renders the collapsible header with sparkles icon and title
    private var headerView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCollapsed.toggle()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)

                Text("AI Suggestions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Renders the appropriate content based on loading/error/results state
    @ViewBuilder
    private var contentView: some View {
        if !isCollapsed {
            Divider()
                .padding(.leading, 20)

            if isLoading {
                loadingView
            } else if let error = error {
                AIErrorView(errorMessage: error)
            } else {
                suggestionsList
            }
        }
    }

    /// Renders the loading indicator with "AI is thinking..." text
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)

            Text("AI is thinking...")
                .font(.subheadline)
                .foregroundColor(.gray)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    /// Renders the list of AI suggestion rows
    private var suggestionsList: some View {
        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, place in
            AISuggestionRow(place: place) {
                onSelectPlace(place)
            }

            if index < suggestions.count - 1 {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
}

// MARK: - AI Error View

/// DUMB Component: Displays an error message with warning icon
private struct AIErrorView: View {
    let errorMessage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)

            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
