//
//  CityDetailSheet.swift
//  loc
//
//  Sheet displaying lists and top places for a specific city.
//

import SwiftUI

/// City detail sheet showing lists and top places for a tapped city annotation.
struct CityDetailSheet: View {
    let cityName: String
    @StateObject private var viewModel: CityDetailViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel

    init(cityName: String) {
        self.cityName = cityName
        self._viewModel = StateObject(wrappedValue: CityDetailViewModel(cityName: cityName))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        listsSection
                        topPlacesSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle(cityName)
            .navigationBarTitleDisplayMode(.large)
            .task {
                if let userId = profileViewModel.user?.id {
                    await viewModel.loadContent(userId: userId)
                }
            }
        }
    }

    /// Loading spinner shown while content is being fetched.
    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.top, 40)
            Spacer()
        }
    }

    /// Section displaying lists that cover this city.
    @ViewBuilder
    private var listsSection: some View {
        if !viewModel.lists.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Lists")
                    .font(.title3)
                    .fontWeight(.bold)

                ForEach(viewModel.lists, id: \.list_id) { list in
                    listRow(list)
                }
            }
        }
    }

    /// Single row for a list item.
    private func listRow(_ list: CityDetailListRecord) -> some View {
        Button {
            PresentationService.shared.present(.list(listId: list.list_id))
        } label: {
            HStack(spacing: 12) {
                listThumbnail(list)

                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(list.place_count) place\(list.place_count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// Thumbnail for a list row.
    private func listThumbnail(_ list: CityDetailListRecord) -> some View {
        Group {
            if let imageUrl = list.image, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    listPlaceholderIcon
                }
            } else {
                listPlaceholderIcon
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Placeholder icon for lists without an image.
    private var listPlaceholderIcon: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.tertiarySystemBackground))
            .overlay(
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            )
    }

    /// Section displaying top places in this city.
    @ViewBuilder
    private var topPlacesSection: some View {
        if !viewModel.topPlaces.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Top Places")
                    .font(.title3)
                    .fontWeight(.bold)

                ForEach(viewModel.topPlaces) { place in
                    topPlaceRow(place)
                }
            }
        }
    }

    /// Single row for a top place item.
    private func topPlaceRow(_ place: CityTopPlace) -> some View {
        HStack(spacing: 12) {
            Text(place.emoji)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(place.placeType.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if place.tiktokCount > 0 {
                Label("\(place.tiktokCount)", systemImage: "play.rectangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
