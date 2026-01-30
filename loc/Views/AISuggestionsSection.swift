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
            VStack(alignment: .leading, spacing: 5) {
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
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.purple.opacity(0.1), .blue.opacity(0.1)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }

    /// Renders the appropriate content based on loading/error/results state
    @ViewBuilder
    private var contentView: some View {
        if !isCollapsed {
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
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
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .padding(.horizontal, 20)
    }

    /// Renders an error message with warning icon
    private func errorView(_ errorMessage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)

            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .padding(.horizontal, 20)
    }

    /// Renders the list of AI suggestion rows
    private var suggestionsList: some View {
        ForEach(suggestions, id: \.id) { place in
            AISuggestionRow(place: place) {
                onSelectPlace(place)
            }
            .padding(.horizontal, 20)
        }
    }
}
