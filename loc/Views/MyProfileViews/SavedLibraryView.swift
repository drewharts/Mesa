//
//  SavedLibraryView.swift
//  loc
//
//  PROTOTYPE (auto_sort_saved). "Saved (beta)": every place the user has, sorted on device by
//  city -> type -> cuisine, with Near you / Saved this week / Dinner in <city> groups.
//  Only reachable for the admin on TestFlight with the PostHog flag on (see SavedLibraryGate).
//

import CoreLocation
import SwiftUI

struct SavedLibraryView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel = SavedLibraryViewModel()
    @State private var selectedPlaceId: String?

    /// How many rows each type section shows in the "All" view before "See all".
    private let sectionPreviewCount = 5

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.library.cities.isEmpty {
                filterBars
                Divider()
            }
            content
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("Saved").font(.headline)
                    Text("BETA")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.mesaAccent.opacity(0.15), in: Capsule())
                        .foregroundColor(.mesaAccent)
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded(userId: userSession.currentUserId, location: locationManager.currentLocation)
        }
        .navigationDestination(item: $selectedPlaceId) { placeId in
            PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: false)
        }
        .analyticsScreen("Saved Beta")
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
                Button("Retry") { Task { await reload() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.library.totalCount == 0 {
            Text("No saved places yet")
                .font(.subheadline).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            placeList
        }
    }

    private var placeList: some View {
        List {
            if viewModel.selectedType == nil {
                ForEach(viewModel.sections, id: \.type) { section in
                    Section {
                        ForEach(section.places.prefix(sectionPreviewCount)) { place in row(place) }
                        if section.places.count > sectionPreviewCount {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { viewModel.selectedType = section.type }
                            } label: {
                                Text("See all \(section.places.count)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.mesaAccent)
                            }
                        }
                    } header: {
                        Text("\(section.type.title) · \(section.places.count)")
                    }
                }
            } else {
                Section {
                    ForEach(viewModel.filteredPlaces) { place in row(place) }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await reload() }
    }

    private func row(_ place: SavedLibraryPlace) -> some View {
        Button {
            selectedPlaceId = place.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: place.type.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.mesaAccent)
                    .frame(width: 32, height: 32)
                    .background(Color.mesaAccent.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    let detail = subtitle(for: place)
                    if !detail.isEmpty {
                        Text(detail).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "Japanese · Brooklyn · 1.2 mi". City is shown only in smart groups (which mix cities).
    private func subtitle(for place: SavedLibraryPlace) -> String {
        var parts: [String] = []
        if let cuisine = place.cuisine { parts.append(cuisine) } else if viewModel.selectedType == nil, case .smart = viewModel.scope { parts.append(place.type.title) }
        if case .smart = viewModel.scope {
            parts.append(place.area ?? place.city)
        } else if let area = place.area {
            parts.append(area)
        }
        if let meters = place.distanceMeters {
            parts.append(TonightRanker.formatDistance(meters, metric: Locale.current.measurementSystem != .us))
        }
        return parts.joined(separator: " · ")
    }

    private func reload() async {
        await viewModel.load(userId: userSession.currentUserId, location: locationManager.currentLocation)
    }

    // MARK: - Filters

    private var filterBars: some View {
        VStack(alignment: .leading, spacing: 8) {
            chipRow {
                ForEach(viewModel.library.smartGroups) { group in
                    chip(group.title, count: group.places.count, selected: viewModel.scope == .smart(group.kind)) {
                        viewModel.scope = .smart(group.kind)
                    }
                }
                ForEach(viewModel.primaryCities) { city in
                    chip(city.name, count: city.places.count, selected: viewModel.scope == .city(city.key)) {
                        viewModel.scope = .city(city.key)
                    }
                }
                if !viewModel.otherCities.isEmpty {
                    Menu {
                        ForEach(viewModel.otherCities) { city in
                            Button("\(city.name) (\(city.places.count))") { viewModel.scope = .city(city.key) }
                        }
                    } label: {
                        let pickedOther: SavedCityGroup? = {
                            guard case .city(let key) = viewModel.scope else { return nil }
                            return viewModel.otherCities.first { $0.key == key }
                        }()
                        chipLabel(pickedOther?.name ?? "More cities", count: pickedOther?.places.count, selected: pickedOther != nil, showsChevron: true)
                    }
                }
            }
            chipRow {
                chip("All", count: viewModel.scopedPlaces.count, selected: viewModel.selectedType == nil) {
                    viewModel.selectedType = nil
                }
                ForEach(viewModel.typeCounts, id: \.type) { item in
                    chip(item.type.title, count: item.count, selected: viewModel.selectedType == item.type) {
                        viewModel.selectedType = item.type
                    }
                }
            }
            if !viewModel.cuisineCounts.isEmpty {
                chipRow {
                    ForEach(viewModel.cuisineCounts, id: \.cuisine) { item in
                        chip(item.cuisine, count: item.count, selected: viewModel.selectedCuisine == item.cuisine, small: true) {
                            viewModel.selectedCuisine = viewModel.selectedCuisine == item.cuisine ? nil : item.cuisine
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func chipRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content() }
                .padding(.horizontal, 16)
        }
    }

    private func chip(_ title: String, count: Int?, selected: Bool, small: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { action() }
        } label: {
            chipLabel(title, count: count, selected: selected, small: small)
        }
        .buttonStyle(.plain)
    }

    private func chipLabel(_ title: String, count: Int?, selected: Bool, small: Bool = false, showsChevron: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title).font((small ? Font.caption : Font.subheadline).weight(.medium))
            if let count {
                Text("\(count)").font(small ? .caption2 : .caption).foregroundColor(selected ? .white.opacity(0.8) : .secondary)
            }
            if showsChevron {
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
        }
        .padding(.horizontal, small ? 10 : 12)
        .padding(.vertical, small ? 5 : 7)
        .foregroundColor(selected ? .white : .primary)
        .background(selected ? Color.mesaAccent : Color(.secondarySystemBackground), in: Capsule())
    }
}

/// Entry row on the user's own profile. Hidden unless SavedLibraryGate passes.
struct SavedLibraryEntryRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 20))
                .foregroundColor(.mesaAccent)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Saved")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("BETA")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.mesaAccent.opacity(0.15), in: Capsule())
                        .foregroundColor(.mesaAccent)
                }
                Text("All your places, sorted by city and type")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}
