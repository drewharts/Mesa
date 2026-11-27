//
//  TripTabActivationModifier.swift
//  loc
//
//  Runs an action when the hosting tab becomes visible again.
//

import SwiftUI

/// Invokes `onActivate` on a false-to-true change of `isActive`.
struct TripTabActivationModifier: ViewModifier {
    let isActive: Bool
    let onActivate: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: isActive) { _, active in
            if active { onActivate() }
        }
    }
}
