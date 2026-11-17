//
//  SearchHeaderView.swift
//  loc
//
//  DUMB Component: Search text field with cancel button and a compact Places | People toggle
//

import SwiftUI

/// DUMB Component: Displays search header with text field and cancel button
/// Single Responsibility: Render search input UI - no business logic
struct SearchHeaderView: View {
    // MARK: - Bindings

    @Binding var searchText: String
    @FocusState.Binding var isFocused: Bool

    // MARK: - Data

    let mode: SearchMode

    // MARK: - Callbacks

    let onModeChange: (SearchMode) -> Void
    let onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                searchField
                cancelButton
            }
            modePicker
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Subviews

    private var modeBinding: Binding<SearchMode> {
        Binding(get: { mode }, set: { onModeChange($0) })
    }

    private var modePicker: some View {
        Picker("Search for", selection: modeBinding) {
            ForEach(SearchMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(maxWidth: 200)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16, weight: .medium))

            TextField(mode.placeholder, text: $searchText)
                .font(.body)
                .foregroundColor(.primary)
                .focused($isFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
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
