//  PlaceSelectionView.swift
//  loc
//
//  SMART Component: Coordinates place selection from photo GPS data.
//  Single Responsibility: Present nearby places and handle selection or creation.

import SwiftUI
import CoreLocation

struct PlaceSelectionView: View {
    @StateObject private var viewModel: PlaceSelectionViewModel
    @Environment(\.dismiss) private var dismiss

    /// Initializes the place selection sheet with required dependencies.
    init(
        photoImportVM: PhotoImportViewModel,
        profileVM: ProfileViewModel,
        selectedPlaceVM: SelectedPlaceViewModel,
        detailPlaceVM: DetailPlaceViewModel
    ) {
        self._viewModel = StateObject(wrappedValue: PlaceSelectionViewModel(
            photoImportVM: photoImportVM,
            profileVM: profileVM,
            selectedPlaceVM: selectedPlaceVM,
            detailPlaceVM: detailPlaceVM
        ))
    }

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                PlaceSelectionPhotoHeader(
                    thumbnail: viewModel.photoThumbnail,
                    placeCount: viewModel.nearbyPlaceCount,
                    isLoading: viewModel.isProcessingPhoto || viewModel.isLoadingNearbyPlaces
                )

                if let coords = viewModel.detectedCoordinates {
                    PlaceSelectionMiniMap(
                        latitude: coords.latitude,
                        longitude: coords.longitude
                    )
                    .padding(.top, 12)
                }

                if viewModel.availableTypeFilters.count >= 2 {
                    PlaceSelectionTypeFilter(
                        types: viewModel.availableTypeFilters,
                        selectedType: viewModel.selectedTypeFilter,
                        onSelectType: { viewModel.filterByType($0) }
                    )
                }

                contentSection
                createPlaceButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cancel()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreatePlacePopup) {
                createPlaceSheet
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isProcessingPhoto || viewModel.isLoadingNearbyPlaces {
            shimmerPlaceholders
        } else if viewModel.filteredPlaces.isEmpty {
            emptyState
        } else {
            placesList
        }
    }

    private var placesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredPlaces) { place in
                    PlaceSelectionRowView(
                        place: place,
                        formattedDistance: viewModel.formatDistance(
                            meters: place.properties.distanceMeters ?? 0
                        ),
                        typeEmoji: viewModel.placeTypeEmoji(for: place),
                        onSelect: { viewModel.selectPlace(place) },
                        isLoading: viewModel.isPlaceBusy
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var shimmerPlaceholders: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                ShimmerView()
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundColor(Color(.systemGray3))

            VStack(spacing: 6) {
                Text("No places found")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Create a new place at this location")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }

    private var createPlaceButton: some View {
        Button {
            viewModel.showCreatePlacePopup = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Create New Place")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(mesaCharcoal)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var createPlaceSheet: some View {
        if let coordinate = viewModel.detectedCoordinates {
            CreatePlacePopupView(
                coordinate: CLLocationCoordinate2D(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            ) { name, description in
                viewModel.createNewPlace(name: name, description: description)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}
