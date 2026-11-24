//
//  ExploreTabView.swift
//  loc
//
//  Explore tab: shortcuts (Tonight, Fresh finds), popular lists near the user, browse by city,
//  and people to follow. Keeps its own NavigationStack; opening a list, a place or another
//  user's profile hands off to the Map tab through the supplied closures.
//

import SwiftUI

struct ExploreTabView: View {
    @StateObject private var viewModel = ExploreTabViewModel()
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager

    /// Opens a list on the map (second argument: also start "Find a table"); returns false when it could not be shown.
    let onOpenList: (ExploreList, Bool) async -> Bool
    let onOpenPlaceDetail: (DetailPlace) -> Void
    let onOpenUser: (String) -> Void
    /// True while the Explore tab is the visible one; a false-to-true change refreshes content.
    var isActive: Bool = true

    @Environment(\.scenePhase) private var scenePhase

    @State private var path = NavigationPath()
    @State private var activeShortcut: ExploreShortcut?

    var body: some View { analyticsBody.analyticsScreen("Explore") }

    private var analyticsBody: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    featuredSection
                    shortcutsRow
                    popularSection
                    citiesSection
                    ExplorePeopleSection(viewModel: viewModel.peopleViewModel, onProfileTap: onOpenUser)
                    statusFooter
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExploreDestination.self) { destination in
                ExploreDestinationView(destination: destination, onListTap: { list in Task { await viewModel.open(list, using: onOpenList) } })
            }
        }
        .task(id: userSession.currentUserId) {
            guard let userId = userSession.currentUserId else { return }
            await viewModel.load(userId: userId, location: locationManager.currentLocation)
        }
        .onChange(of: isActive) { _, active in
            guard active, let userId = userSession.currentUserId else { return }
            Task { await viewModel.refreshIfStale(userId: userId, location: locationManager.currentLocation) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, isActive, let userId = userSession.currentUserId else { return }
            Task { await viewModel.refreshIfStale(userId: userId, location: locationManager.currentLocation) }
        }
        .onChange(of: locationManager.currentLocation) { _, location in
            Task { await viewModel.updateLocation(location) }
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.toastMessage {
                InlineToast(message: message)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.toastMessage)
        .sheet(item: $activeShortcut) { shortcut in
            ExploreShortcutSheetView(shortcut: shortcut) { place in
                activeShortcut = nil
                onOpenPlaceDetail(place)
            }
        }
    }

    // MARK: - Sections

    private var featuredSection: some View {
        VStack(spacing: 16) {
            ForEach(FeaturedLists.all) { config in
                ExploreFeaturedCard(
                    config: config,
                    photoURLs: viewModel.photos(forListId: config.listId),
                    isOpening: viewModel.openingListId == config.listId,
                    onOpen: { Task { await viewModel.openFeatured(config, findTable: false, using: onOpenList) } },
                    onFindTable: { Task { await viewModel.openFeatured(config, findTable: true, using: onOpenList) } }
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private var shortcutsRow: some View {
        HStack(spacing: 12) {
            ExploreShortcutCard(icon: "sparkles", title: "Tonight", subtitle: "3 instant picks", tint: .mesaAccent) {
                Analytics.track(.navTapped, ["item": "tonight", "from": "explore"])
                activeShortcut = .tonight
            }
            ExploreShortcutCard(icon: "rectangle.stack.fill", title: "Fresh finds", subtitle: "Swipe new places", tint: .orange) {
                Analytics.track(.navTapped, ["item": "fresh_finds", "from": "explore"])
                activeShortcut = .freshFinds
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var popularSection: some View {
        if !viewModel.popularLists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderRow(title: viewModel.popularTitle)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(viewModel.popularLists) { list in
                            ExploreListCard(list: list, placePhotoURLs: viewModel.photos(for: list)) { Task { await viewModel.open(list, using: onOpenList) } }
                                .frame(width: 150)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var citiesSection: some View {
        if !viewModel.cities.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderRow(title: "Browse by city")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.cities) { city in
                            ExploreCityCard(city: city, photoURL: viewModel.photoURL(for: city)) { path.append(ExploreDestination.city(city)) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        if viewModel.isLoadingLists && viewModel.popularLists.isEmpty && viewModel.cities.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        } else if viewModel.hasNoLists {
            Text("No public lists to explore yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        }
    }
}
