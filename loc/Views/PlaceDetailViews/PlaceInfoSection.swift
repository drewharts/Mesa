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
    let isDescriptionLoading: Bool
    var onRefresh: (() -> Void)? = nil

    @State private var showingMenu = false
    @State private var showingWebsite = false

    private var hasActionButtons: Bool {
        let hasMenu = place.menuUrl != nil && !place.menuUrl!.isEmpty
        let hasWebsite = place.websiteUrl != nil && !place.websiteUrl!.isEmpty
        let hasPhone = place.phone != nil && !place.phone!.isEmpty
        return hasMenu || hasWebsite || hasPhone
    }

    private func actionButtonLabel(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
            Text(text)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Rating Row (Google/Mapbox)
            if let rating = place.rating, rating > 0 {
                HStack(spacing: 8) {
                    // Google logo
                    Image("GoogleLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)

                    HStack(spacing: 4) {
                        Text(String(format: "%.1f", rating))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)

                        if let count = place.userRatingsTotal, count > 0 {
                            Text("(\(count.formatted()) reviews)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        if let onRefresh {
                            Button(action: onRefresh) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, 8)
            }

            // Description with loading state
            if isDescriptionLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Customizing description...")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .italic()
                }
                .padding(.bottom, 20)
            } else {
                Text(place.description ?? "No description available")
                    .font(.footnote)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)

                // Action buttons (Menu, Website) - horizontal scroll if both present
                if hasActionButtons {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // Menu button
                            if let menuUrl = place.menuUrl, !menuUrl.isEmpty, let url = URL(string: menuUrl) {
                                Button {
                                    showingMenu = true
                                } label: {
                                    actionButtonLabel(icon: "book.pages", text: "Menu")
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showingMenu) {
                                    SafariView(url: url)
                                        .ignoresSafeArea()
                                }
                            }

                            // Website button
                            if let websiteUrl = place.websiteUrl, !websiteUrl.isEmpty, let url = URL(string: websiteUrl) {
                                Button {
                                    showingWebsite = true
                                } label: {
                                    actionButtonLabel(icon: "globe", text: "Website")
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showingWebsite) {
                                    SafariView(url: url)
                                        .ignoresSafeArea()
                                }
                            }

                            // Call button
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
                                    actionButtonLabel(icon: "phone.fill", text: "Call")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
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

    return PlaceInfoSection(place: mockPlace, isDescriptionLoading: false)
        .padding()
}

