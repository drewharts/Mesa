//
//  PlaceListPopupView.swift
//  loc
//
//  Reusable Component: Generic popup container for displaying paginated place lists
//  Used by: ExternalPlacesPopupView, ReviewsListPopupView, and future popup views
//  DUMB Component: Pure display, all data provided via parameters
//
//  Usage:
//  PlaceListPopupView(
//      title: "Saved Videos",
//      count: profile.totalExternalPlacesCount,
//      isLoading: profile.isLoadingExternalPlaces,
//      isLoadingMore: profile.isLoadingMoreExternalPlaces,
//      places: profile.lightweightExternalPlaces,
//      hasMore: profile.hasMoreExternalPlaces,
//      emptyIcon: "video",
//      emptyTitle: "No Videos Yet",
//      emptyMessage: "Places you add from videos will appear here",
//      loadMore: { await profile.loadMoreExternalPlaces() },
//      cardBuilder: { place, navigate in PopupPlaceCard(place: place, onNavigate: navigate, ...) }
//  )

import SwiftUI
import Combine

struct PlaceListPopupView<CardView: View, HeaderAccessory: View>: View {
    // MARK: - Configuration
    let title: String
    let count: Int?
    let isLoading: Bool
    let isLoadingMore: Bool
    let places: [LightweightPlace]
    let hasMore: Bool
    let emptyIcon: String
    let emptyTitle: String
    let emptyMessage: String
    let loadMore: () async -> Void
    let onBackToProfile: (() -> Void)?  // Optional: Shows "Profile" button when provided
    let onViewOnMap: (() -> Void)?  // Optional: Shows "Map" button when provided
    @ViewBuilder let cardBuilder: (LightweightPlace, @escaping (String) -> Void) -> CardView
    @ViewBuilder let headerAccessory: () -> HeaderAccessory

    @Environment(\.presentationMode) var presentationMode

    /// Observed for pending place navigation when map annotation is tapped while sheet is open.
    @ObservedObject private var presentationService = PresentationService.shared

    /// Initializes the popup view with all configuration options.
    init(
        title: String,
        count: Int? = nil,
        isLoading: Bool,
        isLoadingMore: Bool,
        places: [LightweightPlace],
        hasMore: Bool,
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        loadMore: @escaping () async -> Void,
        onBackToProfile: (() -> Void)? = nil,
        onViewOnMap: (() -> Void)? = nil,
        @ViewBuilder cardBuilder: @escaping (LightweightPlace, @escaping (String) -> Void) -> CardView,
        @ViewBuilder headerAccessory: @escaping () -> HeaderAccessory
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
        self.onViewOnMap = onViewOnMap
        self.cardBuilder = cardBuilder
        self.headerAccessory = headerAccessory
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
            VStack(spacing: 0) {
                header
                ScrollView {
                    content
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250)
                    .id(placeId)
            }
        }
        .onReceive(presentationService.$pendingPlaceNavigation.compactMap { $0 }) { placeId in
            // When map annotation is tapped while sheet is open, replace the current place detail.
            // Uses onReceive (Combine) instead of onChange for reliable delivery even when
            // a navigation destination is pushed on the stack.
            var newPath = NavigationPath()
            newPath.append(placeId)
            navigationPath = newPath
            presentationService.pendingPlaceNavigation = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                // Back button on left (external profile popups only)
                if let backAction = onBackToProfile {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        backAction()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 44, height: 44)
                }

                // Title
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Spacer()

                // Header accessory inline (e.g. filter buttons)
                headerAccessory()

                // Action buttons
                HStack(alignment: .center, spacing: 12) {
                    // View on Map button (profile popups only)
                    if let viewOnMap = onViewOnMap {
                        Button(action: viewOnMap) {
                            Image(systemName: "map")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 44, height: 44)
                    }

                    // Close button on right (current user popups only)
                    if onBackToProfile == nil {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 44, height: 44)
                    }
                }
            }

            // Place count below the title row
            if let count = count {
                Text("\(count) place\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, -8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
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

    /// Triggers pagination when scrolling near the end of the list.
    private func triggerPaginationIfNeeded(index: Int) {
        // Trigger at exactly the 3rd-to-last item (matches LightweightListPopupView pattern)
        // Exact match prevents auto-re-triggering after loads complete
        guard index == places.count - 3 && hasMore && !isLoadingMore else { return }
        Task { await loadMore() }
    }
}

// MARK: - Convenience Init (No Header Accessory)

extension PlaceListPopupView where HeaderAccessory == EmptyView {
    /// Convenience initializer without header accessory (backward compatible).
    init(
        title: String,
        count: Int? = nil,
        isLoading: Bool,
        isLoadingMore: Bool,
        places: [LightweightPlace],
        hasMore: Bool,
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        loadMore: @escaping () async -> Void,
        onBackToProfile: (() -> Void)? = nil,
        onViewOnMap: (() -> Void)? = nil,
        @ViewBuilder cardBuilder: @escaping (LightweightPlace, @escaping (String) -> Void) -> CardView
    ) {
        self.init(
            title: title,
            count: count,
            isLoading: isLoading,
            isLoadingMore: isLoadingMore,
            places: places,
            hasMore: hasMore,
            emptyIcon: emptyIcon,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            loadMore: loadMore,
            onBackToProfile: onBackToProfile,
            onViewOnMap: onViewOnMap,
            cardBuilder: cardBuilder,
            headerAccessory: { EmptyView() }
        )
    }
}
