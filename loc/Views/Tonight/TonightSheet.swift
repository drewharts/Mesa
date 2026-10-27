//
//  TonightSheet.swift
//  loc
//
//  "Where should we go?" — 3 picks from your and your friends' saves, shown
//  instantly on open. One optional vibe chip row; one button to send the picks
//  to the group chat as a live vote.
//

import SwiftUI

struct TonightSheet: View {
    @StateObject private var viewModel: TonightViewModel
    let onOpenPlace: (DetailPlace) -> Void
    @Environment(\.dismiss) private var dismiss

    init(userSession: UserSession, locationManager: LocationManager, onOpenPlace: @escaping (DetailPlace) -> Void) {
        _viewModel = StateObject(wrappedValue: TonightViewModel(userSession: userSession, locationManager: locationManager))
        self.onOpenPlace = onOpenPlace
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            TonightVibeChipRow(selected: viewModel.vibe) { viewModel.selectVibe($0) }
            content
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .task { await viewModel.loadIfNeeded() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.vibe.headline)
                    .font(.title2.weight(.bold))
                Text(viewModel.hasLocation ? "From your & your friends' saves nearby" : "From your & your friends' saves")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in TonightPickCardSkeleton() }
            }
            .padding(.horizontal, 20)
        case .empty(let message):
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 24)
        case .loaded(let picks):
            VStack(spacing: 10) {
                ForEach(Array(picks.enumerated()), id: \.element.id) { index, pick in
                    TonightPickCard(pick: pick, rank: index + 1) { onOpenPlace(pick.place) }
                }
                groupButton
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
        }
    }

    private var groupButton: some View {
        Button {
            Task { await viewModel.startGroupPick() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSharing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "person.3.fill")
                }
                Text("Ask the group")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSharing)
    }
}
