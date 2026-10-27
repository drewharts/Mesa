//
//  GroupPickSheet.swift
//  loc
//
//  Live group vote. Everyone taps yes/no once per place; Mesa decides the
//  winner automatically (everyone voted, a clear winner, or time ran out),
//  pushes everyone, and this sheet updates on its own to show the result.
//  "More options" swaps in the next best saves; "Add place" and "Invite"
//  switch the same sheet to a sub-screen (no nested sheets).
//

import SwiftUI
import UIKit

struct GroupPickSheet: View {
    @StateObject private var viewModel: GroupPickViewModel
    let onOpenPlace: (DetailPlace) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        pickId: String,
        userId: String? = nil,
        locationManager: LocationManager? = nil,
        onOpenPlace: @escaping (DetailPlace) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: GroupPickViewModel(pickId: pickId, userId: userId, locationManager: locationManager))
        self.onOpenPlace = onOpenPlace
    }

    var body: some View {
        Group {
            switch viewModel.mode {
            case .vote:
                voteScreen
            case .addPlace:
                GroupPickAddPlaceView(viewModel: viewModel)
            case .invite:
                GroupPickInviteView(viewModel: viewModel)
            }
        }
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await viewModel.resume() }
        }
    }

    // MARK: - Vote / result screen

    private var voteScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    content
                    feedback
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in TonightPickCardSkeleton() }
            }
        } else if let pick = viewModel.pick {
            if !pick.members.isEmpty {
                GroupPickMembersStrip(pick: pick, currentUserId: viewModel.currentUserId)
            }
            if pick.hasWinner {
                GroupPickResultView(
                    pick: pick,
                    winner: viewModel.winner,
                    note: viewModel.decisionNote,
                    currentUserId: viewModel.currentUserId,
                    onOpenPlace: { place in
                        Analytics.track(.groupPickPlaceOpened, ["source": "result"])
                        onOpenPlace(place)
                    },
                    onDirections: { place in
                        Analytics.track(.groupPickDirectionsTapped)
                        PlaceDirections.open(place)
                    }
                )
            } else if pick.isDecided {
                noMatchCard
            } else if let waiting = viewModel.waitingText {
                Text(waiting)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if pick.hasWinner {
                Text("All options")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
            }
            voteRows(pick)
            if !pick.isDecided {
                actionRow
            }
        }
    }

    private func voteRows(_ pick: GroupPick) -> some View {
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
    }

    /// Closed with no yes votes: offer the two ways forward.
    private var noMatchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No match yet 🤔")
                .font(.title3.weight(.bold))
            Text(viewModel.decisionNote ?? "Nobody said yes to any of these.")
                .font(.footnote)
                .foregroundColor(.secondary)
            Button {
                Task { await viewModel.suggestMoreOptions() }
            } label: {
                Label("Show 3 more options", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isWorking)
            Button {
                Task { await viewModel.beginAddPlace() }
            } label: {
                Label("Add a place", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.primary)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.systemGray5)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    /// More options / Add place / Invite, one tap each.
    private var actionRow: some View {
        HStack(spacing: 8) {
            actionButton("More options", systemImage: "arrow.triangle.2.circlepath") {
                Task { await viewModel.suggestMoreOptions() }
            }
            .disabled(viewModel.isWorking || !viewModel.canAddMore)
            actionButton("Add place", systemImage: "plus") {
                Task { await viewModel.beginAddPlace() }
            }
            .disabled(!viewModel.canAddMore)
            actionButton("Invite", systemImage: "person.badge.plus") {
                Task { await viewModel.beginInvite() }
            }
        }
        .padding(.top, 2)
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.primary)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var feedback: some View {
        if viewModel.isWorking {
            ProgressView().frame(maxWidth: .infinity)
        }
        if let notice = viewModel.notice {
            Text(notice)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        if let error = viewModel.errorMessage {
            Text(error)
                .font(.footnote)
                .foregroundColor(.red)
        }
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
}
