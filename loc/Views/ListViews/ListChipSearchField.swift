//
//  ListChipSearchField.swift
//  loc
//
//  DUMB Component: the first item of a list's chip row. A magnifying-glass button that expands in place into a
//  focused text field with a clear/close (x) button, and collapses back to the button.
//

import SwiftUI

struct ListChipSearchField: View {
    @Binding var query: String
    let isActive: Bool
    let onActivate: () -> Void
    /// The (x) button: clears typed text, or closes the field when it is already empty.
    let onClearOrClose: () -> Void
    /// The keyboard was dismissed with nothing typed.
    let onCollapse: () -> Void

    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 36

    static let expandedWidth: CGFloat = 220

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isActive ? .secondary : .primary)
            if isActive {
                TextField("Search categories", text: $query)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onSubmit { isFocused = false }
                    .transition(.opacity)
                Button(action: onClearOrClose) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(query.isEmpty ? "Close search" : "Clear search")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, isActive ? 12 : 0)
        .frame(width: isActive ? Self.expandedWidth : height, height: height)
        .background(Capsule().fill(Color(.systemGray6)))
        .contentShape(Capsule())
        .onTapGesture { if !isActive { onActivate() } }
        .accessibilityElement(children: isActive ? .contain : .ignore)
        .accessibilityLabel("Search categories")
        .accessibilityAddTraits(isActive ? AccessibilityTraits() : AccessibilityTraits.isButton)
        .onChange(of: isActive) { _, active in
            guard active else { return isFocused = false }
            Task { @MainActor in isFocused = true }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused && isActive && query.isEmpty { onCollapse() }
        }
    }
}
