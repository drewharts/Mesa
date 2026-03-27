//
//  FeedCardFrontView.swift
//  loc
//
//  DUMB Component: Photo side of a feed card.
//  Single Responsibility: Display review photos with user/place header and carousel.
//

import SwiftUI

struct FeedCardFrontView: View {
    let item: FeedItem
    let onComment: () -> Void
    let onZoom: (Int) -> Void
    let onProfileTapped: () -> Void
    let onPlaceTapped: () -> Void
    let isCrowned: Bool
    let crownCount: Int
    let onCrown: () -> Void

    @State private var currentIndex: Int? = 0
    @State private var didTriggerZoom: Bool = false

    private var userInitial: String {
        String(item.userFirstName.prefix(1)).uppercased()
    }

    private var fullName: String {
        "\(item.userFirstName) \(item.userLastName)".trimmingCharacters(in: .whitespaces)
    }

    private var relativeTimestamp: String {
        let seconds = Date().timeIntervalSince(item.timestamp)
        if seconds < 60 { return "Just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return "\(hours)h" }
        let days = Int(seconds / 86400)
        return "\(days)d"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            photoCarousel
            captionRow
            actionBar
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            Button(action: onProfileTapped) {
                CachedProfileImage(
                    url: item.profilePhotoUrl,
                    size: 32,
                    fallbackInitial: userInitial
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Button(action: onProfileTapped) {
                    Text(fullName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Button(action: onPlaceTapped) {
                    Text(item.placeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Photo Carousel

    private var photoCarousel: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * 5.0 / 4.0

            ZStack(alignment: .bottom) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(0..<item.imageUrls.count, id: \.self) { index in
                            CachedAsyncImage(url: URL(string: item.imageUrls[index]), targetSize: nil) {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .overlay(ProgressView())
                            }
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()
                            .contentShape(Rectangle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $currentIndex)
                .scrollIndicators(.hidden)
                .frame(height: height)

                if item.imageUrls.count > 1 {
                    pageIndicator
                }
            }
            .frame(height: height)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipped()
        .simultaneousGesture(pinchToZoomGesture)
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<item.imageUrls.count, id: \.self) { index in
                Circle()
                    .fill(index == (currentIndex ?? 0) ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.black.opacity(0.3)))
        .padding(.bottom, 10)
    }

    // MARK: - Caption

    @ViewBuilder
    private var captionRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !item.caption.isEmpty {
                Button(action: onComment) {
                    Text(item.caption)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            Text(relativeTimestamp)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button(action: onComment) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 16))
                    if item.commentCount > 0 {
                        Text("\(item.commentCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: onCrown) {
                HStack(spacing: 4) {
                    Image(systemName: isCrowned ? "crown.fill" : "crown")
                        .font(.system(size: 16))
                        .foregroundColor(isCrowned ? .yellow : .secondary)
                    if crownCount > 0 {
                        Text("\(crownCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Pinch Gesture

    private var pinchToZoomGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.15)
            .onChanged { value in
                if value.magnification > 1.1, !didTriggerZoom {
                    didTriggerZoom = true
                    onZoom(currentIndex ?? 0)
                }
            }
            .onEnded { _ in
                didTriggerZoom = false
            }
    }
}
