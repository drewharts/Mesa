//
//  TabSheetHeaderContent.swift
//  loc
//
//  DUMB Component: the pushed-destination layout of the tab sheet's header strip. Back chevron and a bold,
//  truncating title on the left, share on the top right, and an optional creator chip + detail line beneath
//  the title (indented to align with it) so no horizontal space is wasted.
//

import SwiftUI

/// Back / title / share row with an optional creator-chip detail line.
struct TabSheetHeaderContent: View {
    let header: TabSheetHeader

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            titleRow
            if header.hasDetailLine { detailRow }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Subviews

    private var titleRow: some View {
        HStack(spacing: 2) {
            Button(action: header.onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            Text(header.title)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            if let onShare = header.onShare {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Share")
            }
        }
    }

    private var detailRow: some View {
        HStack(spacing: 6) {
            if let creator = header.creator {
                ListCreatorChip(name: creator.name, photoURL: creator.photoURL, onTap: creator.onTap)
            }
            if let detail = header.detail {
                Text(header.creator == nil ? detail : "· \(detail)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 38)
    }
}
