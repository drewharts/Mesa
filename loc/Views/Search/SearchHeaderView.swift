//
//  SearchHeaderView.swift
//  loc
//
//  DUMB Component: Search text field with cancel button
//

import SwiftUI

/// DUMB Component: Displays search header with text field and cancel button
/// Single Responsibility: Render search input UI - no business logic
struct SearchHeaderView: View {
    // MARK: - Bindings

    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    // MARK: - Callbacks

    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            searchField
            cancelButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16, weight: .medium))

            TextField("Search places, users...", text: $searchText)
                .font(.body)
                .foregroundColor(.primary)
                .focused($isFocused)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("Cancel")
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}
