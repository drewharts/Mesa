//
//  ListsSearchBar.swift
//  loc
//
//  DUMB Component: Search bar with text field and cancel button.
//  Single Responsibility: Render the search input with dismiss capability.
//

import SwiftUI

struct ListsSearchBar: View {
    // MARK: - Parameters

    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding
    var onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            searchCapsule
            cancelButton
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Search Capsule

    private var searchCapsule: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))

            TextField("Search lists...", text: $searchText)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(isFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.systemGray5).opacity(0.6))
        )
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button("Cancel") {
            onCancel()
        }
        .font(.subheadline)
        .foregroundColor(.primary)
    }
}
