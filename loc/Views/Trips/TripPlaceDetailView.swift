//
//  TripPlaceDetailView.swift
//  loc
//
//  Inline place detail view for the trip planner bottom half
//

import SwiftUI

/// Displays place details inline within the trip planner when a place is tapped.
struct TripPlaceDetailView: View {
    @StateObject private var viewModel: TripPlaceDetailViewModel

    init(placeId: String) {
        self._viewModel = StateObject(wrappedValue: TripPlaceDetailViewModel(placeId: placeId))
    }

    var body: some View {
        placeContent
            .task {
                await viewModel.loadPlace()
            }
    }

    // MARK: - Content

    /// Displays loading, error, or place detail content based on ViewModel state.
    @ViewBuilder
    private var placeContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading place...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error {
            errorView(message: error)
        } else if let place = viewModel.place {
            placeDetailScrollView(place: place)
        }
    }

    /// Error state with retry option.
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await viewModel.loadPlace() }
            }
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Scrollable place detail layout with hero photo, name, address, and info section.
    private func placeDetailScrollView(place: DetailPlace) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                heroPhoto(place: place)
                placeHeader(place: place)

                PlaceInfoSection(place: place, isDescriptionLoading: false)

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
    }

    /// Hero photo loaded from the place's first photo URL.
    @ViewBuilder
    private func heroPhoto(place: DetailPlace) -> some View {
        if let photoUrl = place.photoUrls?.first, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        ProgressView()
                    )
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Place name and address header.
    private func placeHeader(place: DetailPlace) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.title2)
                .fontWeight(.bold)

            if let address = place.address, !address.isEmpty {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
