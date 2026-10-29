//
//  FreshFindsView.swift
//  loc
//
//  "Fresh finds": a full-bleed swipeable card stack of places people just imported from
//  TikTok / Instagram. Swipe right (or tap the heart) saves, swipe left skips, tap a card to
//  peek the full place detail over the stack without losing your spot.
//  Shown automatically once after sign-in; reachable from the sparkles button on the map.
//

import SwiftUI

struct FreshFindsView: View {
    let userId: String?
    /// Leaves the stack and shows the place on the map.
    var onShowOnMap: ((DetailPlace) -> Void)?

    @StateObject private var viewModel = FreshFindsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGSize = .zero
    @State private var peekPlaceId: PeekID?
    @State private var savedToast = false

    private struct PeekID: Identifiable { let id: String }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                if viewModel.isLoading {
                    loadingCard
                } else if viewModel.cards.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(viewModel.cards.prefix(3).enumerated().reversed()), id: \.element.id) { index, card in
                        cardView(card, depth: index)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)

            if !viewModel.cards.isEmpty {
                actionBar
            }
        }
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            if savedToast {
                Label("Saved", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { await viewModel.start() }
        .onChange(of: viewModel.cards.first?.id) { _, newId in
            guard let card = viewModel.cards.first, newId != nil else { return }
            Analytics.track(.discoveryCardViewed, ["place_id": card.item.placeId, "source": card.item.source, "position": viewModel.swipeCount + 1])
        }
        .sheet(item: $peekPlaceId) { peek in
            NavigationStack {
                PlaceDetailViewInNavigation(placeId: peek.id, minSheetHeight: 250, shouldAnimateMap: false)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { peekPlaceId = nil }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .analyticsScreen("Fresh Finds")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fresh finds")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Just imported from TikTok & Instagram")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Map") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    // MARK: - Card

    @ViewBuilder
    private func cardView(_ card: FreshFind, depth: Int) -> some View {
        let isTop = depth == 0
        let offset = isTop ? dragOffset : .zero
        let rotation = isTop ? Double(dragOffset.width / 22) : 0

        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                Image(uiImage: card.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.75)],
                           startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                sourceBadge(card.item.source)
                Text(card.item.placeName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if !card.item.subtitle.isEmpty {
                    Text(card.item.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(20)

            if isTop { swipeStamp }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(isTop ? 0.18 : 0.08), radius: 16, y: 8)
        .scaleEffect(1 - CGFloat(depth) * 0.04)
        .offset(x: offset.width, y: offset.height * 0.3 + CGFloat(depth) * 14)
        .rotationEffect(.degrees(rotation))
        .allowsHitTesting(isTop)
        .contentShape(Rectangle())
        .onTapGesture {
            Analytics.track(.discoveryPlaceOpened, ["place_id": card.item.placeId])
            peekPlaceId = PeekID(id: card.item.placeId)
        }
        .gesture(isTop ? dragGesture(for: card) : nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.cards.map(\.id))
    }

    private func sourceBadge(_ source: String) -> some View {
        let label = source.lowercased().contains("insta") ? "Instagram" : (source.lowercased().contains("tik") ? "TikTok" : "Video")
        return HStack(spacing: 4) {
            Image(systemName: "play.fill").font(.system(size: 9, weight: .bold))
            Text(label).font(.caption2.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var swipeStamp: some View {
        let progress = min(abs(dragOffset.width) / 120, 1)
        if dragOffset.width > 10 {
            stamp("SAVE", color: .green).opacity(progress)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(24)
        } else if dragOffset.width < -10 {
            stamp("SKIP", color: .white).opacity(progress)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(24)
        }
    }

    private func stamp(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 3))
    }

    private func dragGesture(for card: FreshFind) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let w = value.translation.width + value.predictedEndTranslation.width * 0.2
                if w > 110 {
                    commit(card, direction: "right")
                } else if w < -110 {
                    commit(card, direction: "left")
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dragOffset = .zero }
                }
            }
    }

    private func commit(_ card: FreshFind, direction: String) {
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: direction == "right" ? 600 : -600, height: dragOffset.height)
        }
        if direction == "right" { saveCard(card, via: "swipe") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.swipe(card, direction: direction)
            dragOffset = .zero
        }
    }

    private func saveCard(_ card: FreshFind, via: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            if await viewModel.save(card, userId: userId, via: via) {
                withAnimation(.spring()) { savedToast = true }
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                withAnimation(.easeOut) { savedToast = false }
            }
        }
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 28) {
            circleButton("xmark", tint: .secondary, size: 56) {
                if let card = viewModel.cards.first { commit(card, direction: "left") }
            }
            circleButton("info", tint: .primary, size: 46) {
                if let card = viewModel.cards.first {
                    Analytics.track(.discoveryPlaceOpened, ["place_id": card.item.placeId])
                    peekPlaceId = PeekID(id: card.item.placeId)
                }
            }
            circleButton("heart.fill", tint: .pink, size: 56) {
                if let card = viewModel.cards.first { commit(card, direction: "right") }
            }
        }
        .padding(.top, 18)
    }

    private func circleButton(_ icon: String, tint: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(tint)
                .frame(width: size, height: size)
                .background(Color(.secondarySystemBackground), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - States

    private var loadingCard: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay(ProgressView())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 36)).foregroundColor(.orange)
            Text(viewModel.swipeCount > 0 ? "You're all caught up" : "Nothing new yet")
                .font(.title3.weight(.semibold))
            Text("Share a TikTok or Reel to Mesa to import places.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Explore the map") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
        }
        .padding(32)
    }
}
