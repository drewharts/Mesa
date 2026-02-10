//
//  GoogleMapsImportPlaceRow.swift
//  loc
//
//  Created by Claude on 2/9/26.
//
//  DUMB Component: Displays a single place in the import review list.
//  Single Responsibility: Renders place name, address, status, and selection state.
//

import SwiftUI

/// A row displaying an imported place with its resolution status and selection checkbox.
struct GoogleMapsImportPlaceRow: View {
    let place: ResolvedImportPlace
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                selectionIndicator
                placeInfo
                Spacer()
                statusBadge
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    // MARK: - Subviews

    private var selectionIndicator: some View {
        ZStack {
            if place.isSelected && isMatched {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 22))
            } else if isMatched {
                Circle()
                    .stroke(Color.gray, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red.opacity(0.6))
                    .font(.system(size: 22))
            }
        }
    }

    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(displayName)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(1)

            if let address = displayAddress {
                Text(address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if case .failed(let reason) = place.status {
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }

    private var statusBadge: some View {
        Group {
            switch place.status {
            case .pending, .resolving:
                ProgressView()
                    .scaleEffect(0.7)
            case .matched:
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .font(.system(size: 12, weight: .bold))
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
            }
        }
    }

    // MARK: - Computed Properties

    private var displayName: String {
        if case .matched(let detail) = place.status {
            return detail.name
        }
        return place.originalPlace.name
    }

    private var displayAddress: String? {
        if case .matched(let detail) = place.status {
            return detail.address
        }
        return place.originalPlace.address
    }

    private var isMatched: Bool {
        if case .matched = place.status { return true }
        return false
    }

    private var isDisabled: Bool {
        switch place.status {
        case .pending, .resolving, .failed:
            return true
        case .matched:
            return false
        }
    }
}
