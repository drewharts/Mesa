//
//  PlaceListPopupView.swift
//  loc
//
//  Reusable Component: Generic popup container for displaying paginated place lists
//  Used by: TikToksPopupView, ReviewsListPopupView, and future popup views
//  DUMB Component: Pure display, all data provided via parameters
//
//  Usage:
//  PlaceListPopupView(
//      title: "TikToks",
//      count: profile.totalExternalPlacesCount,
//      isLoading: profile.isLoadingTikTokPlaces,
//      isLoadingMore: profile.isLoadingMoreExternalPlaces,
//      places: profile.lightweightExternalPlaces,
//      hasMore: profile.hasMoreExternalPlaces,
//      emptyIcon: "video",
//      emptyTitle: "No TikToks Yet",
//      emptyMessage: "Places you add from TikTok videos will appear here",
//      loadMore: { await profile.loadMoreExternalPlaces() },
//      cardBuilder: { place, navigate in PopupPlaceCard(place: place, onNavigate: navigate, ...) }
//  )

import SwiftUI

struct PlaceListPopupView<CardView: View>: View {
    // MARK: - Configuration
    let title: String
    let count: Int
    let isLoading: Bool
    let isLoadingMore: Bool
    let places: [LightweightPlace]
    let hasMore: Bool
    let emptyIcon: String
    let emptyTitle: String
    let emptyMessage: String
    let loadMore: () async -> Void
    let onBackToProfile: (() -> Void)?  // Optional: Shows "Profile" button when provided
    @ViewBuilder let cardBuilder: (LightweightPlace, @escaping (String) -> Void) -> CardView

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var mapViewModel: MapViewModel

    // Default initializer with optional onBackToProfile
    init(
        title: String,
        count: Int,
        isLoading: Bool,
        isLoadingMore: Bool,
        places: [LightweightPlace],
        hasMore: Bool,
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        loadMore: @escaping () async -> Void,
        onBackToProfile: (() -> Void)? = nil,
        @ViewBuilder cardBuilder: @escaping (LightweightPlace, @escaping (String) -> Void) -> CardView
    ) {
        self.title = title
        self.count = count
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.places = places
        self.hasMore = hasMore
        self.emptyIcon = emptyIcon
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.loadMore = loadMore
        self.onBackToProfile = onBackToProfile
        self.cardBuilder = cardBuilder
    }

    // Navigation state for place detail navigation
    @State private var navigationPath = NavigationPath()

    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    content
                }
            }
            .onChange(of: places.count) {
                // Re-check pagination when places count changes (after load completes)
                if places.count > 0 {
                    triggerPaginationIfNeeded(index: places.count - 1)
                }
            }
            .onChange(of: isLoadingMore) { newValue in
                // When loading finishes, if at end and more data exists, trigger next load
                if !newValue && hasMore && !places.isEmpty {
                    triggerPaginationIfNeeded(index: places.count - 1)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250)
            }
        }
        .onChange(of: mapViewModel.pendingPlaceNavigation) { oldValue, newValue in
            // When map annotation is tapped while popup is open, navigate to that place
            if let placeId = newValue {
                navigationPath.append(placeId)
                mapViewModel.pendingPlaceNavigation = nil
            }
        }
    }
    
    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                // For external user popups: show "< Profile" back button
                // For current user popups: show X close button
                if let backAction = onBackToProfile {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        backAction()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Profile")
                        }
                        .foregroundColor(.primary)
                    }
                } else {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text("\(count) place\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 10)
    }
    
    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading && places.isEmpty {
            loadingView
        } else if places.isEmpty {
            emptyView
        } else {
            gridView

            // Pagination loading indicator
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Text("Loading \(title)...")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: emptyIcon)
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            Text(emptyTitle)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    // MARK: - Grid View
    // Note: No ScrollView or VStack wrapper - allows LazyVGrid to load items lazily
    // Parent body provides the ScrollView for scroll position preservation

    private var gridView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                cardBuilder(place, { placeId in
                    navigationPath.append(placeId)
                })
                .onAppear {
                    triggerPaginationIfNeeded(index: index)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Pagination Helper
    
    private func triggerPaginationIfNeeded(index: Int) {
        // Trigger when within 6 items of the end (aggressive prefetch for smooth infinite scroll)
        guard index >= places.count - 6 && hasMore && !isLoadingMore else { return }
        Task { await loadMore() }
    }
}

