//
//  GroupPickAddPlaceView.swift
//  loc
//
//  Sub-screen of the group pick sheet: search your and your friends' saved
//  places and add one to the vote with a single tap.
//

import SwiftUI

struct GroupPickAddPlaceView: View {
    @ObservedObject var viewModel: GroupPickViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { viewModel.mode = .vote } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                Text("Add a place")
                    .font(.title2.weight(.bold))
                Spacer()
            }
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search your saved places", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.systemGray6)))
            .padding(.horizontal, 20)

            if let notice = viewModel.notice {
                Text(notice).font(.footnote).foregroundColor(.secondary).padding(.horizontal, 20)
            }
            if let error = viewModel.errorMessage {
                Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, 20)
            }

            if viewModel.isLoadingSaved {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
                Spacer(minLength: 0)
            } else {
                let rows = viewModel.addablePlaces
                if rows.isEmpty {
                    Text(viewModel.searchText.isEmpty ? "No saved places to add." : "No saved place matches that.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(rows, id: \.placeId) { row in
                                Button {
                                    Task { await viewModel.addPlace(placeId: row.placeId) }
                                } label: {
                                    rowLabel(row.place)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isWorking)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func rowLabel(_ place: DetailPlace) -> some View {
        HStack(spacing: 12) {
            TonightPlaceThumbnail(place: place, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.primary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}
