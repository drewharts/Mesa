//
//  ExploreListHeaderView.swift
//  loc
//
//  DUMB Component: compact header of a list pushed inside the Explore sheet. One row with back, the
//  left-aligned title and share; a second line with the creator chip and the place count.
//

import SwiftUI

/// Two-line list header: [back] Title ... [share], then creator chip · count.
struct ExploreListHeaderView: View {
    let title: String
    let countLabel: String
    let creatorName: String?
    let creatorPhotoURL: String?
    let isOwnList: Bool
    let onBack: () -> Void
    let onShare: () -> Void
    /// Opens the creator's profile; nil when the creator is unknown.
    let onCreatorTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleRow
            creatorRow
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Subviews

    private var titleRow: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            Text(title)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Share list")
        }
    }

    private var creatorRow: some View {
        HStack(spacing: 6) {
            creatorChip
            Text("· \(countLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .padding(.leading, 40)
    }

    @ViewBuilder
    private var creatorChip: some View {
        if isOwnList {
            ListCreatorChip(name: "You", photoURL: creatorPhotoURL, onTap: nil)
        } else if let creatorName, !creatorName.isEmpty {
            ListCreatorChip(name: creatorName, photoURL: creatorPhotoURL, onTap: onCreatorTap)
        }
    }
}
