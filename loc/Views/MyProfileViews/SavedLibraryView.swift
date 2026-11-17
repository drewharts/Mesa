//
//  SavedLibraryView.swift
//  loc
//
//  auto_sort_saved. "Saved": every place the user has, sorted on device into ONE entry per city
//  (plus Near you / Saved this week / Dinner in <city>). Opening a city shows its places with
//  horizontally scrolling type and cuisine chips. On for everyone unless the PostHog kill switch is set
//  (see SavedLibraryGate).
//

import Combine
import SwiftUI

struct SavedLibraryView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var profile: ProfileViewModel
    @StateObject private var viewModel = SavedLibraryViewModel()

    var body: some View {
        content
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadIfNeeded(userId: userSession.currentUserId, location: locationManager.currentLocation)
            }
            // A one-tap save (or unsave) from a place page re-sorts the library.
            .onReceive(profile.favoritesViewModel.$userFavorites.removeDuplicates().dropFirst()) { _ in
                Task { await viewModel.load(userId: userSession.currentUserId, location: locationManager.currentLocation) }
            }
            .analyticsScreen("Saved")
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if viewModel.isLoading && viewModel.library.cities.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Sorting your places").font(.subheadline).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.loadError, viewModel.library.cities.isEmpty {
            VStack(spacing: 12) {
                Text(error).font(.subheadline).foregroundColor(.secondary)
                Button("Retry") { Task { await viewModel.load(userId: userSession.currentUserId, location: locationManager.currentLocation) } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.library.totalCount == 0 {
            Text("No saved places yet")
                .font(.subheadline).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            cityList
        }
    }

    private var cityList: some View {
        List {
            if !viewModel.library.smartGroups.isEmpty {
                Section {
                    ForEach(viewModel.library.smartGroups) { group in
                        NavigationLink {
                            SavedCityDetailView(title: group.title, places: group.places, ordering: viewModel.ordering(for: group), showsCity: true)
                        } label: {
                            SavedCityRow(title: group.title, subtitle: "", count: group.places.count, systemImage: group.kind.systemImage)
                        }
                    }
                }
            }
            Section("Cities") {
                ForEach(viewModel.cities) { city in
                    NavigationLink {
                        SavedCityDetailView(title: city.name, places: city.places, ordering: .nearest, showsCity: false)
                    } label: {
                        SavedCityRow(title: city.name, subtitle: viewModel.summary(for: city), count: city.places.count, systemImage: "building.2")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.load(userId: userSession.currentUserId, location: locationManager.currentLocation) }
    }
}
