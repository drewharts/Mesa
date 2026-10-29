//
//  PlaceInsightsSection.swift
//  loc
//
//  Top of the place page: friends first, the short take, and "People order".
//

import SwiftUI

struct PlaceInsightsSection: View {
    @ObservedObject var viewModel: PlaceInsightsViewModel
    /// The take is shown in PlaceInfoSection by default; enable to show it here instead.
    var showTake: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.friends.isEmpty {
                friendsSection
            }
            if showTake, let take = viewModel.take {
                takeSection(take)
            }
            // Dish chips only; the TikTok source rows duplicated the Videos section below.
            if !viewModel.topDishes.isEmpty {
                peopleOrderSection
            }
        }
    }

    // MARK: Friends

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Friends who've been")
                .font(.headline)
            ForEach(viewModel.friends.prefix(5)) { friend in
                FriendActivityRow(friend: friend)
            }
            if viewModel.friends.count > 5 {
                Text("+\(viewModel.friends.count - 5) more")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Take

    private func takeSection(_ take: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.orange)
            Text(take)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: People order

    private var peopleOrderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("People order")
                .font(.headline)
            if !viewModel.topDishes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.topDishes, id: \.name) { dish in
                            Text(dish.count > 1 ? "\(dish.name) ×\(dish.count)" : dish.name)
                                .font(.footnote.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}

private struct FriendActivityRow: View {
    let friend: FriendPlaceActivity

    private var subtitle: String {
        var parts: [String] = []
        if let lists = friend.listNames, !lists.isEmpty {
            parts.append("On " + lists.prefix(2).joined(separator: ", "))
        } else if friend.saved == true {
            parts.append("Saved")
        }
        if let dishes = friend.favoriteDishes, !dishes.isEmpty {
            parts.append("Loves " + dishes.prefix(2).joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: URL(string: friend.profilePhotoUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(Color(.systemGray5))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.fullName ?? "Friend")
                        .font(.subheadline.weight(.semibold))
                    if let rating = friend.rating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let review = friend.reviewText, !review.isEmpty {
                    Text("“\(review)”")
                        .font(.footnote)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MentionRow: View {
    let mention: PlaceMention
    @Environment(\.openURL) private var openURL

    private var detail: String {
        [mention.tip, mention.vibe]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        Button {
            if let s = mention.sourceUrl, let url = URL(string: s) { openURL(url) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                AsyncImage(url: URL(string: mention.thumbnailUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5))
                }
                .frame(width: 44, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    if let dishes = mention.dishes, !dishes.isEmpty {
                        Text(dishes.joined(separator: ", "))
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Text(sourceLabel)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .disabled(mention.sourceUrl == nil)
    }

    private var sourceLabel: String {
        var label = "View on TikTok"
        if let author = mention.author, !author.isEmpty { label += " · @\(author.replacingOccurrences(of: "@", with: ""))" }
        if let t = mention.timestampSeconds, t > 0 { label += String(format: " · %d:%02d", t / 60, t % 60) }
        return label
    }
}
