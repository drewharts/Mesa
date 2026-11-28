//
//  OpenStatusBadgeView.swift
//  loc
//
//  Created by Cursor on 12/14/24.
//  Reusable badge component for displaying place open/closed status.
//  Pure display component - receives data via parameters, no business logic.
//

import SwiftUI

struct OpenStatusBadgeView: View {
    
    // MARK: - Properties
    
    let status: OpenStatus
    var onTap: (() -> Void)? = nil
    /// Optional secondary text shown after the status, e.g. "Closes 11 PM".
    var detailText: String? = nil

    private var label: String {
        if case .alwaysOpen = status { return status.displayText }
        guard let detailText, !detailText.isEmpty else { return status.displayText }
        return "\(status.displayText) · \(detailText)"
    }
    
    // MARK: - Body

    var body: some View {
        if status.shouldDisplay {
            Button(action: { onTap?() }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Computed Properties
    
    private var dotColor: Color {
        switch status {
        case .open, .alwaysOpen:
            return .green
        case .closingSoon:
            return .orange
        case .openingSoon:
            return .blue
        case .closed:
            return .red
        case .temporarilyClosed, .permanentlyClosed:
            return .gray
        case .unknown:
            return .clear
        }
    }
}

// MARK: - Preview

#Preview("Open") {
    OpenStatusBadgeView(status: .open)
        .padding()
}

#Preview("Closed") {
    OpenStatusBadgeView(status: .closed)
        .padding()
}

#Preview("Closing Soon") {
    OpenStatusBadgeView(status: .closingSoon(minutesRemaining: 15))
        .padding()
}

#Preview("Opening Soon") {
    OpenStatusBadgeView(status: .openingSoon(minutesRemaining: 10))
        .padding()
}

#Preview("Always Open") {
    OpenStatusBadgeView(status: .alwaysOpen)
        .padding()
}

#Preview("Temporarily Closed") {
    OpenStatusBadgeView(status: .temporarilyClosed)
        .padding()
}

#Preview("All Statuses") {
    VStack(spacing: 12) {
        OpenStatusBadgeView(status: .open)
        OpenStatusBadgeView(status: .closed)
        OpenStatusBadgeView(status: .closingSoon(minutesRemaining: 15))
        OpenStatusBadgeView(status: .openingSoon(minutesRemaining: 10))
        OpenStatusBadgeView(status: .alwaysOpen)
        OpenStatusBadgeView(status: .temporarilyClosed)
        OpenStatusBadgeView(status: .permanentlyClosed)
    }
    .padding()
}
