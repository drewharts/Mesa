//
//  VisiblePlacesPopupView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//
//  Shows places currently visible on the map with Friends/Community filter toggle.
//  
//  Architecture:
//  - View owns ViewModel via @StateObject
//  - View acts as coordinator: extracts data from EnvironmentObjects and configures ViewModel
//  - ViewModel depends only on services (SRP), not other ViewModels
//  - Grid cells are dumb components with callbacks
//

import SwiftUI
import MapKit

struct VisiblePlacesPopupView: View {
    
    // MARK: - Input
    
    let mapRegion: MKCoordinateRegion?
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject private var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject private var mapViewModel: MapViewModel
    @EnvironmentObject private var profile: ProfileViewModel
    
    // MARK: - ViewModel (owned by this View)
    
    @StateObject private var viewModel = VisiblePlacesPopupViewModel()
    
    // MARK: - Layout
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                filterPicker
                contentSection
            }
            .navigationBarHidden(true)
        }
        .onAppear(perform: configureViewModel)
        .onChange(of: viewModel.selectedFilter) { _ in
            viewModel.resetImageLoading()
        }
    }
    
    // MARK: - ViewModel Configuration
    
    /// Coordinator pattern: View extracts data from EnvironmentObjects and configures ViewModel
    /// This keeps ViewModel decoupled from other ViewModels (SRP)
    private func configureViewModel() {
        viewModel.configure(
            friendsAnnotations: mapViewModel.viewportAnnotations,
            communityMarkers: mapViewModel.communityMarkers,
            mapRegion: mapRegion,
            existingPlaceImages: detailPlaceViewModel.placeImages
        )
        viewModel.onAppear()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Spacer()
            Text("Places in View")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Filter Picker
    
    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.selectedFilter) {
            ForEach(VisiblePlacesFilter.allCases) { filter in
                Label(filter.rawValue, systemImage: filter.icon)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
    
    // MARK: - Content Section
    
    @ViewBuilder
    private var contentSection: some View {
        if !viewModel.visiblePlaces.isEmpty {
            placesGrid
        } else {
            emptyStateView
        }
    }
    
    private var placesGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(viewModel.visiblePlaces.enumerated()), id: \.element.id) { index, item in
                    gridCell(for: item, at: index)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Grid Cells (Dumb Components with Callbacks)
    
    @ViewBuilder
    private func gridCell(for item: VisiblePlaceItem, at index: Int) -> some View {
        Group {
            switch item.source {
            case .friends:
                FriendsPlaceGridCell(
                    item: item,
                    image: viewModel.getImage(for: item.id),
                    onTap: { handlePlaceTap(item) }
                )
            case .community:
                CommunityPlaceGridCell(
                    item: item,
                    image: viewModel.getImage(for: item.id),
                    onTap: { handlePlaceTap(item) }
                )
            }
        }
        .onAppear {
            viewModel.onCellAppear(index: index)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: viewModel.selectedFilter == .friends ? "person.2" : "globe")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No \(viewModel.selectedFilter.rawValue.lowercased()) places in view")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(emptyStateHint)
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding(.vertical, 30)
    }
    
    private var emptyStateHint: String {
        switch viewModel.selectedFilter {
        case .friends:
            return "Try zooming out or panning to see more places from your network"
        case .community:
            return "Try zooming out to discover places saved by the community"
        }
    }
    
    // MARK: - Actions
    
    /// Handle place tap - loads full details and navigates
    private func handlePlaceTap(_ item: VisiblePlaceItem) {
        Task {
            do {
                let fullPlace = try await viewModel.loadPlaceDetails(for: item)
                
                await MainActor.run {
                    selectedPlaceVM.selectPlaceAndFetchDetails(fullPlace, shouldAnimateMap: true)
                    selectedPlaceVM.isDetailSheetPresented = true
                    dismiss()
                }
            } catch {
                print("❌ [VisiblePlacesPopup] Error loading place details: \(error)")
            }
        }
    }
}
