//
//  NearbyDiscoverySheet.swift
//  loc
//
//  Sheet view displaying nearby place discovery results as a list.
//  Users tap a row to create a placeholder and navigate to place detail.
//

import SwiftUI
import MapKit

struct NearbyDiscoverySheet: View {
    @ObservedObject private var viewModel = NearbyDiscoverySheetViewModel.shared
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.isLoading {
                loadingContent
            } else {
                listContent
            }
        }
        .onDisappear {
            viewModel.clear()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Nearby Places")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                }
                .frame(width: 44, height: 44)
            }

            if !viewModel.isLoading {
                Text("\(viewModel.mapItems.count) place\(viewModel.mapItems.count == 1 ? "" : "s") nearby")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, -8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Loading Content

    private var loadingContent: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Finding nearby places...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.mapItems, id: \.self) { mapItem in
                    NearbyPlaceCard(
                        mapItem: mapItem,
                        searchCoordinate: viewModel.searchCoordinate,
                        onTap: { viewModel.selectMapItem(mapItem) }
                    )
                    Divider()
                        .padding(.leading, 70)
                }
            }
        }
    }
}
