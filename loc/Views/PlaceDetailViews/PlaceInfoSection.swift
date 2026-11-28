//
//  PlaceInfoSection.swift
//  loc
//
//  Created by Cursor on 1/22/25.
//  Pure display component - no business logic, no ViewModel needed
//

import SwiftUI

struct PlaceInfoSection: View {
    let place: DetailPlace
    var isRefreshing: Bool = false
    var onRefresh: (() -> Void)? = nil
    var onAddPost: (() -> Void)? = nil
    /// Opens the private note editor; the Note pill is hidden when nil.
    var onNoteTapped: (() -> Void)? = nil
    /// Short AI take (vibe + tips); replaces the generic description when available.
    var takeText: String? = nil
    /// Reservation link (Resy/OpenTable/...) when available; the button is hidden otherwise.
    var reservation: ReservationLink? = nil
    var onReserveTapped: (() -> Void)? = nil
    /// damnlines.com wait-time data for tracked NYC venues; the row is hidden when nil.
    var waitInfo: DamnlinesWaitInfo? = nil

    @Environment(\.openURL) private var openURL

    @State private var showingMenu = false
    @State private var showingWebsite = false

    /// Summary text, or nil when the place has none (the line collapses).
    private var summaryText: String? {
        let text: String = (takeText ?? place.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ratingRow
            if let summaryText {
                Text(summaryText)
                    .font(.footnote)
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .lineSpacing(0)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actionRow
            if let waitInfo {
                DamnlinesWaitRow(info: waitInfo)
            }
        }
    }

    // MARK: - Rating

    /// Google rating, review count and refresh control on one line.
    @ViewBuilder
    private var ratingRow: some View {
        if let rating = place.rating, rating > 0 {
            HStack(spacing: 6) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 12)
                Text(String(format: "%.1f", rating))
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                if let count = place.userRatingsTotal, count > 0 {
                    Text("(\(count.formatted()))")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                refreshButton
            }
        }
    }

    @ViewBuilder
    private var refreshButton: some View {
        if let onRefresh {
            Button(action: onRefresh) {
                if isRefreshing {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
    }

    // MARK: - Actions

    /// Horizontally scrolling row: Reserve, Menu, Website, Call, Review, Note.
    private var actionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                reserveButton
                menuButton
                websiteButton
                callButton
                reviewButton
                noteButton
            }
        }
    }

    @ViewBuilder
    private var reserveButton: some View {
        if let reservation, let url = reservation.destinationURL {
            Button {
                onReserveTapped?()
                openURL(url)
            } label: {
                ReserveActionLabel(link: reservation)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("place.detail.reserve")
        }
    }

    @ViewBuilder
    private var menuButton: some View {
        if let menuUrl = place.menuUrl, !menuUrl.isEmpty, let url = URL(string: menuUrl) {
            Button { showingMenu = true } label: {
                PlaceActionPillLabel(icon: "book.pages", text: "Menu")
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingMenu) {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var websiteButton: some View {
        if let websiteUrl = place.websiteUrl, !websiteUrl.isEmpty, let url = URL(string: websiteUrl) {
            Button { showingWebsite = true } label: {
                PlaceActionPillLabel(icon: "globe", text: "Website")
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingWebsite) {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var callButton: some View {
        if let phone = place.phone, !phone.isEmpty {
            Button {
                let cleanedPhone = phone.replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                if let url = URL(string: "tel://\(cleanedPhone)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                PlaceActionPillLabel(icon: "phone.fill", text: "Call")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("place.detail.call")
        }
    }

    @ViewBuilder
    private var reviewButton: some View {
        if let onAddPost {
            Button(action: onAddPost) {
                PlaceActionPillLabel(icon: "square.and.pencil", text: "Review", isProminent: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("place.detail.writeReview")
        }
    }

    @ViewBuilder
    private var noteButton: some View {
        if let onNoteTapped {
            Button(action: onNoteTapped) {
                PlaceActionPillLabel(icon: "note.text", text: "Note", iconOnly: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("place.detail.note")
        }
    }
}

// MARK: - Preview (Super Simple!)
#Preview {
    var mockPlace = DetailPlace()
    mockPlace.name = "Sample Restaurant"
    mockPlace.description = "A cozy Italian restaurant serving authentic pasta and pizza in a warm, family-friendly atmosphere."
    mockPlace.rating = 4.5
    mockPlace.userRatingsTotal = 234

    return PlaceInfoSection(place: mockPlace)
        .padding()
}

