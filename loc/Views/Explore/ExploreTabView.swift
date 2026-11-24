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

    let onOpenList: (ExploreList) -> Void
    let onOpenListFindTable: (ExploreList) -> Void
    let onOpenPlaceDetail: (DetailPlace) -> Void
    let onOpenUser: (String) -> Void

    @State private var path = NavigationPath()
    @State private var activeShortcut: ExploreShortcut?

    var body: some View { analyticsBody.analyticsScreen("Explore") }

    private var analyticsBody: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    compactTitle
                    featuredSection
                    shortcutsRow
                    popularSection
                    citiesSection
                    ExplorePeopleSection(viewModel: viewModel.peopleViewModel, onProfileTap: onOpenUser)
                    statusFooter
                }
                .padding(.top, 2)
                .padding(.bottom, 12)
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExploreDestination.self) { destination in
                ExploreDestinationView(destination: destination, onListTap: onOpenList)
            }
            .refreshable {
                guard let userId = userSession.currentUserId else { return }
                await viewModel.refresh(userId: userId, location: locationManager.currentLocation)
            }
        }
        .task(id: userSession.currentUserId) {
            guard let userId = userSession.currentUserId else { return }
            await viewModel.load(userId: userId, location: locationManager.currentLocation)
        }
        .onChange(of: locationManager.currentLocation) { _, location in
            Task { await viewModel.updateLocation(location) }
        }
        .sheet(item: $activeShortcut) { shortcut in
            ExploreShortcutSheetView(shortcut: shortcut) { place in
                activeShortcut = nil
                onOpenPlaceDetail(place)
            }
        }
    }

    // MARK: - Sections

    /// Compact title shown right under the sheet's grabber instead of a large navigation title.
    private var compactTitle: some View {
        Text("Explore")
            .font(.title2.weight(.bold))
            .padding(.horizontal, 16)
    }

    private var featuredSection: some View {
        VStack(spacing: 16) {
            ForEach(FeaturedLists.all) { config in
                ExploreFeaturedCard(
                    config: config,
                    photoURLs: viewModel.photos(forListId: config.listId),
                    onOpen: { Task { await viewModel.openFeatured(config, using: onOpenList) } },
                    onFindTable: { Task { await viewModel.openFeatured(config, using: onOpenListFindTable) } }
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
                            ExploreListCard(list: list, placePhotoURLs: viewModel.photos(for: list)) { onOpenList(list) }
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
