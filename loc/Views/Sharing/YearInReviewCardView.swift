//
//  YearInReviewCardView.swift
//  loc
//
//  Shareable recap card showing the user's Mesa activity stats.
//  Rendered to UIImage for sharing via Messages/Instagram.
//

import SwiftUI

struct YearInReviewCardView: View {
    let userName: String
    let stats: YearInReviewStats

    private let burntOrange = Color(red: 0.8, green: 0.4, blue: 0.1)
    private let cardWidth: CGFloat = 400
    private let cardHeight: CGFloat = 560

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            statsGrid
            footerSection
        }
        .padding(28)
        .frame(width: cardWidth, height: cardHeight)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.8, green: 0.4, blue: 0.1),
                    Color(red: 0.6, green: 0.25, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow)
            Text("\(userName)'s Mesa Recap")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                statTile(value: "\(stats.placesReviewed)", label: "Places Reviewed", icon: "mappin.circle.fill")
                statTile(value: "\(stats.placesFavorited)", label: "Favorites", icon: "heart.fill")
            }
            HStack(spacing: 16) {
                statTile(value: "\(stats.listsCreated)", label: "Lists Created", icon: "list.bullet")
                statTile(value: "\(stats.videosImported)", label: "Videos Imported", icon: "play.rectangle.fill")
            }
            HStack(spacing: 16) {
                statTile(value: "\(stats.crownsReceived)", label: "Crowns Received", icon: "crown.fill")
                statTile(value: "\(stats.citiesCount)", label: "Cities Explored", icon: "globe.americas.fill")
            }
            if let topCity = stats.topCity, !topCity.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    Text("Top City: \(topCity)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.top, 4)
            }
        }
    }

    private var footerSection: some View {
        Text("Mesa")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white.opacity(0.7))
    }

    /// Renders a single stat tile with icon, value, and label.
    private func statTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.yellow)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
}
