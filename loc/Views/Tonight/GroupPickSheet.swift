//
//  GroupPickSheet.swift
//  loc
//
//  Live group vote. Everyone taps yes/no once per place; Mesa decides the
//  winner automatically (everyone voted, or time ran out) and this sheet
//  updates on its own to show it.
//

import SwiftUI

struct GroupPickSheet: View {
    @StateObject private var viewModel: GroupPickViewModel
    let onOpenPlace: (DetailPlace) -> Void
    @Environment(\.dismiss) private var dismiss

    init(pickId: String, onOpenPlace: @escaping (DetailPlace) -> Void) {
        _viewModel = StateObject(wrappedValue: GroupPickViewModel(pickId: pickId))
        self.onOpenPlace = onOpenPlace
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if viewModel.isLoading {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in TonightPickCardSkeleton() }
                }
                .padding(.horizontal, 20)
            } else if let pick = viewModel.pick {
                if let winner = viewModel.winner {
                    winnerBanner(winner)
                }
                VStack(spacing: 10) {
                    ForEach(pick.placeIds, id: \.self) { placeId in
                        let place = viewModel.place(for: placeId)
                        GroupPickVoteRow(
                            name: place?.name ?? "Loading…",
                            place: place,
                            tally: pick.tally(for: placeId),
                            myVote: pick.myVote(for: placeId),
                            isWinner: pick.decidedPlaceId?.lowercased() == placeId.lowercased(),
                            isDecided: pick.isDecided,
                            onVote: { yes in Task { await viewModel.vote(placeId: placeId, yes: yes) } },
                            onOpen: { if let place { onOpenPlace(place) } }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.pick?.title ?? "Group pick")
                    .font(.title2.weight(.bold))
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let url = GroupPickService.shared.shareURL(pickId: viewModel.pickId), viewModel.pick?.isDecided == false {
                ShareLink(item: url, message: Text("Tap to vote on where we go")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
    }

    private func winnerBanner(_ winner: DetailPlace) -> some View {
        Button { onOpenPlace(winner) } label: {
            HStack(spacing: 14) {
                TonightPlaceThumbnail(place: winner, size: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text("It's decided 🎉")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                    Text(winner.name)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.primary)
                    if let address = winner.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.green.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}
