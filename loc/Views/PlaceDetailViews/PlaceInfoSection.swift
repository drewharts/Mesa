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

    @State private var showingMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Rating Row (Google/Mapbox)
            if let rating = place.rating, rating > 0 {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.subheadline)
                            .foregroundColor(.yellow)

                        Text(String(format: "%.1f", rating))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)

                        if let count = place.userRatingsTotal, count > 0 {
                            Text("(\(count.formatted()) reviews)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }

                    // Google logo
                    Image("GoogleLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
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

                // Menu button - only show if menu URL exists
                if let menuUrl = place.menuUrl, !menuUrl.isEmpty, let url = URL(string: menuUrl) {
                    Button {
                        showingMenu = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.pages")
                                .font(.system(size: 14, weight: .medium))
                            Text("Menu")
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
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                    .sheet(isPresented: $showingMenu) {
                        SafariView(url: url)
                            .ignoresSafeArea()
                    }
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

