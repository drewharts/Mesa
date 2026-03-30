//
//  TasteProfileCardView.swift
//  loc
//
//  Shareable card showing the user's place taste breakdown.
//  Rendered to UIImage for sharing via Messages/Instagram.
//

import SwiftUI

struct TasteProfileCardView: View {
    let userName: String
    let entries: [(entry: TasteProfileEntry, percentage: Double)]
    let totalPlaces: Int

    private let burntOrange = Color(red: 0.8, green: 0.4, blue: 0.1)
    private let cardWidth: CGFloat = 400
    private let cardHeight: CGFloat = 520

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            barsSection
            footerSection
        }
        .padding(28)
        .frame(width: cardWidth, height: cardHeight)
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.93, blue: 0.9), .white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("\(userName)'s Taste")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            Text("\(totalPlaces) places explored")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var barsSection: some View {
        VStack(spacing: 10) {
            ForEach(entries.prefix(6), id: \.entry.id) { item in
                HStack(spacing: 10) {
                    Text(item.entry.emoji)
                        .font(.system(size: 18))
                        .frame(width: 28)

                    Text(item.entry.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 80, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(burntOrange.opacity(0.8))
                            .frame(width: geo.size.width * item.percentage / 100)
                    }
                    .frame(height: 20)

                    Text("\(Int(item.percentage))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }

    private var footerSection: some View {
        Text("Mesa")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(burntOrange)
    }
}
