//
//  PlaceCorrectionSheet.swift
//  loc
//
//  Single Responsibility: Purely declarative UI for place correction/assignment.
//  MVVM: All business logic lives in PlaceCorrectionViewModel.

import SwiftUI

struct PlaceCorrectionSheet: View {
    @StateObject private var viewModel: PlaceCorrectionViewModel

    /// Callback when place is successfully changed - passes the resolved DetailPlace.
    var onPlaceChanged: ((DetailPlace) -> Void)?

    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) var dismiss

    init(mode: PlaceAssignmentMode, onPlaceChanged: ((DetailPlace) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: PlaceCorrectionViewModel(mode: mode))
        self.onPlaceChanged = onPlaceChanged
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.needsVideoSelection && !viewModel.hasSelectedVideo {
                    videoSelectorContent
                } else {
                    currentPlaceHeader
                    searchSection
                    searchResultsList
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(viewModel.isUpdating)
            .overlay {
                if viewModel.isUpdating {
                    updatingOverlay
                }
            }
            .onChange(of: viewModel.didComplete) { _, completed in
                if completed, let place = viewModel.resolvedPlace {
                    profile.externalContentViewModel.refreshExternalPlacesAfterImport()
                    dismiss()
                    onPlaceChanged?(place)
                }
            }
        }
    }

    // MARK: - Video Selector

    /// Displays video thumbnails so the user can pick which video to correct.
    private var videoSelectorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which video has the wrong place?")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 16)

            Text("Tap the video you'd like to correct")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            videosGrid
        }
    }

    /// Displays a scrollable grid of video thumbnails for selection.
    private var videosGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.enrichedVideos, id: \.videoID) { video in
                    Button {
                        viewModel.selectVideo(video)
                    } label: {
                        VideoThumbnailCard(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .onAppear {
            viewModel.loadVideoThumbnails()
        }
    }

    // MARK: - Current Place Header

    /// Displays context about the current place (correction) or missing place (new assignment).
    private var currentPlaceHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.headerLabelText)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: viewModel.headerIconName)
                            .foregroundColor(.gray)
                            .font(.title2)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.headerTitle)
                        .font(.headline)
                        .lineLimit(2)

                    Text(viewModel.headerSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Search Section

    /// Displays the search input field with live results.
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search for correct place")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 16)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search places...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.performSearch(query: newValue)
                    }

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }

                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }

    // MARK: - Search Results

    /// Displays search results as a selectable list.
    private var searchResultsList: some View {
        List {
            if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty && !viewModel.isSearching {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.searchResults, id: \.id) { suggestion in
                    Button {
                        viewModel.selectPlace(suggestion)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suggestion.name)
                                    .font(.body)
                                    .foregroundColor(.primary)

                                if let address = suggestion.address {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Updating Overlay

    /// Shows a loading overlay while the place association is being persisted.
    private var updatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Updating place...")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemGray2))
            .cornerRadius(12)
        }
    }
}
