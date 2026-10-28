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
    @State private var showPlanner = false
    let onOpenPlace: (DetailPlace) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showAllPicks = false

    init(userSession: UserSession, locationManager: LocationManager, onOpenPlace: @escaping (DetailPlace) -> Void) {
        _viewModel = StateObject(wrappedValue: TonightViewModel(userSession: userSession, locationManager: locationManager))
        self.onOpenPlace = onOpenPlace
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Vibe chips and results first; recent group picks collapsed below.
                    TonightVibeChipRow(selected: viewModel.vibe) { viewModel.selectVibe($0) }
                    content
                    if !viewModel.myPicks.isEmpty {
                        myPicksSection
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 16)
        .task { await viewModel.loadIfNeeded() }
        .sheet(isPresented: $showPlanner) { PlanGroupPickView(viewModel: viewModel) }
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
                if viewModel.openingLaterMode {
                    Text("Nothing that fits is open right now. Opening soon:")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(picks.enumerated()), id: \.element.id) { index, pick in
                    TonightPickCard(pick: pick, rank: index + 1) { onOpenPlace(pick.place) }
                }
                if viewModel.canShowMore {
                    moreOptionsButton
                }
                groupButton
                    .padding(.top, 2)
                planButton
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Your picks

    /// Active and decided group picks, so a result is never lost.
    private var myPicksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation { showAllPicks.toggle() } } label: {
                HStack {
                    Text("Your group picks").font(.subheadline.weight(.semibold))
                    Spacer()
                    if viewModel.myPicks.count > 1 {
                        Text(showAllPicks ? "Less" : "\(viewModel.myPicks.count)")
                            .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                        Image(systemName: showAllPicks ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            ForEach(showAllPicks ? viewModel.myPicks : Array(viewModel.myPicks.prefix(1))) { summary in
                Button { viewModel.openPick(summary) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: summary.hasWinner ? "party.popper.fill" : (summary.needsMyVote ? "hand.thumbsup.fill" : "clock.fill"))
                            .font(.system(size: 18))
                            .foregroundColor(summary.hasWinner ? .green : (summary.needsMyVote ? .orange : .secondary))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.headline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Text(summary.statusLine)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private var moreOptionsButton: some View {
        Button { viewModel.showMoreOptions() } label: {
            Label("More options", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.primary)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }

    /// Start a ranked group pick for a future date (defaults: next Friday, top 3 preselected).
    private var planButton: some View {
        Button { showPlanner = true } label: {
            Label("Plan for later", systemImage: "calendar.badge.plus")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.primary)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.systemGray5)))
        }
        .buttonStyle(.plain)
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
