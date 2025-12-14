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
    
    // MARK: - Body
    
    var body: some View {
        if status.shouldDisplay {
            Button(action: { onTap?() }) {
                HStack(spacing: 4) {
                    Text(status.displayText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(textColor)
                    
                    // Show chevron if tappable
                    if onTap != nil {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(textColor.opacity(0.8))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(backgroundColor)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Computed Properties
    
    private var textColor: Color {
        switch status {
        case .open, .alwaysOpen:
            return .white
        case .closingSoon:
            return .white
        case .openingSoon:
            return .white
        case .closed:
            return .white
        case .temporarilyClosed, .permanentlyClosed:
            return .white
        case .unknown:
            return .clear
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .open, .alwaysOpen:
            return Color.green
        case .closingSoon:
            return Color.orange
        case .openingSoon:
            return Color.blue
        case .closed:
            return Color.red.opacity(0.8)
        case .temporarilyClosed, .permanentlyClosed:
            return Color.gray
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
