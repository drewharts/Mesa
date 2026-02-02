//
//  RoundedCornerShape.swift
//  loc
//
//  Custom shape for applying corner radius to specific corners.
//

import SwiftUI
import UIKit

/// Shape for selective corner radius on a rectangle.
struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    /// Creates a path with rounded corners for the specified corners.
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Extension

extension View {
    /// Applies corner radius to specific corners of the view.
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}
