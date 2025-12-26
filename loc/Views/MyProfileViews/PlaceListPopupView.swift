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
//      cardBuilder: { place in PopupPlaceCard(place: place, ...) }
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
    @ViewBuilder let cardBuilder: (LightweightPlace) -> CardView
    
    @Environment(\.presentationMode) var presentationMode
    
    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                content
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
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
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                    cardBuilder(place)
                        .onAppear {
                            triggerPaginationIfNeeded(index: index)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
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
        .onChange(of: places.count) {
            // Re-check pagination when places count changes (after load completes)
            // This handles the case where user is already at the bottom
            if places.count > 0 {
                triggerPaginationIfNeeded(index: places.count - 1)
            }
        }
        .onChange(of: isLoadingMore) { newValue in
            // When loading finishes (newValue is false), if we are still at the end
            // and more data exists, trigger the next load immediately.
            if !newValue && hasMore && !places.isEmpty {
                triggerPaginationIfNeeded(index: places.count - 1)
            }
        }
    }
    
    // MARK: - Pagination Helper
    
    private func triggerPaginationIfNeeded(index: Int) {
        // Trigger when within 6 items of the end (aggressive prefetch for smooth infinite scroll)
        guard index >= places.count - 6 && hasMore && !isLoadingMore else { return }
        Task { await loadMore() }
    }
}

