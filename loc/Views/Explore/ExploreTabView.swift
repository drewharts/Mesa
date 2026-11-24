//
//  ExploreTabView.swift
//  loc
//
//  Explore tab: shortcuts (Tonight, Fresh finds), popular lists near the user, browse by city,
//  and people to follow. Keeps its own NavigationStack: lists, places, cities and profiles are all
//  pushed onto it (back or edge-swipe returns to the Explore content where it was); while a list is
//  pushed the map shows its pins.
//

import SwiftUI

struct ExploreTabView: View {
    @StateObject private var viewModel = ExploreTabViewModel()
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var mapDisplayCoordinatorVM: MapDisplayCoordinatorViewModel
    @StateObject private var navigation = ExploreNavigationViewModel()

    let onOpenPlaceDetail: (DetailPlace) -> Void
    /// True while the Explore tab is the visible one; a false-to-true change refreshes content.
    var isActive: Bool = true

    @Environment(\.scenePhase) private var scenePhase

    @State private var activeShortcut: ExploreShortcut?

    var body: some View { analyticsBody.analyticsScreen("Explore") }

    private var analyticsBody: some View {
        NavigationStack(path: $navigation.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    featuredSection
                    shortcutsRow
                    popularSection
                    citiesSection
                    ExplorePeopleSection(viewModel: viewModel.peopleViewModel, onProfileTap: { navigation.openProfile($0) })
                    statusFooter
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExploreDestination.self) { destination in
                ExploreDestinationView(
                    destination: destination,
                    onListTap: { navigation.openList($0) },
                    onPlaceTap: { navigation.openPlace($0) }
                )
            }
        }
        .onAppear { navigation.bind(mapCoordinator: mapDisplayCoordinatorVM) }
        .onChange(of: navigation.path) { _, _ in navigation.syncMapWithPath() }
        .onReceive(PresentationService.shared.$pendingPlaceNavigation.compactMap { $0 }) { navigation.handleMapPinTap($0) }
        .task(id: userSession.currentUserId) {
            guard let userId = userSession.currentUserId else { return }
            await viewModel.load(userId: userId, location: locationManager.currentLocation)
        }
        .onChange(of: isActive) { _, active in navigation.setActive(active) }
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

    /// Pushes a list (and with the flag, opens its "Find a table" form).
    private var openList: (ExploreList, Bool) -> Void {
        { navigation.openList($0, startFindTable: $1) }
    }

    // MARK: - Sections

    private var featuredSection: some View {
        VStack(spacing: 16) {
            ForEach(FeaturedLists.all) { config in
                ExploreFeaturedCard(
                    config: config,
                    photoURLs: viewModel.photos(forListId: config.listId),
                    isOpening: viewModel.openingListId == config.listId,
                    onOpen: { Task { await viewModel.openFeatured(config, findTable: false, using: openList) } },
                    onFindTable: { Task { await viewModel.openFeatured(config, findTable: true, using: openList) } }
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
                            ExploreListCard(list: list, placePhotoURLs: viewModel.photos(for: list)) { navigation.openList(list) }
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
                            ExploreCityCard(city: city, photoURL: viewModel.photoURL(for: city)) { navigation.openCity(city) }
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
