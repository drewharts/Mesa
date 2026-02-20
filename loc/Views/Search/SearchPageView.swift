//
//  SearchPageView.swift
//  loc
//
//  Full-screen search page (Google Maps style)
//

import SwiftUI

/// Full-screen search page view
/// Single Responsibility: Container for search UI with NavigationStack for user profiles
struct SearchPageView: View {
    // MARK: - ViewModel

    @ObservedObject var viewModel: SearchPageViewModel

    // MARK: - Focus State

    @FocusState private var isSearchFocused: Bool

    // MARK: - Computed Properties

    /// Binding to searchText through the ViewModel chain
    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.searchViewModel.searchText },
            set: { viewModel.searchViewModel.searchText = $0 }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchHeaderView(
                    searchText: searchTextBinding,
                    isFocused: $isSearchFocused,
                    onCancel: {
                        isSearchFocused = false
                        viewModel.dismiss()
                    }
                )

                SearchContentView(
                    searchViewModel: viewModel.searchViewModel,
                    onSelectPlace: { place in
                        isSearchFocused = false
                        viewModel.handlePlaceSelection(place)
                        viewModel.dismiss()
                    },
                    onSelectUser: { user in
                        isSearchFocused = false
                        viewModel.handleUserSelection(user)
                    },
                    onViewAllKeywords: viewModel.handleViewAllKeywords,
                    onSelectCoordinate: { coordinate in
                        isSearchFocused = false
                        viewModel.handleCoordinateSelection(coordinate)
                    }
                )
                .padding(.top, 8)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.searchViewModel.setupIfNeeded()
            viewModel.searchViewModel.searchText = ""
            isSearchFocused = true
        }
    }
}
