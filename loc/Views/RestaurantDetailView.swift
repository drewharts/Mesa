//
//  RestaurantDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

import SwiftUI
import GooglePlaces

struct RestaurantDetailView: View {
    let place: GMSPlace
    @Binding var sheetHeight: CGFloat
    let minSheetHeight: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            if sheetHeight == minSheetHeight {
                // Collapsed State Content
                Text(place.name ?? "Unknown")
                    .font(.title)
                    .foregroundColor(.blue)
                    .padding()
            } else {
                // Expanded State Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                                Text(place.name ?? "Unknown")
                                    .font(.title)
                                    .foregroundStyle(.blue)
                                    .bold()
                            Spacer()
                            Button(action: {
                                // Directions action
                            }) {
                                Text("Directions")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                    .padding(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray, lineWidth: 2)
                                    )
                            }
                            Button(action: {
                                // Add action
                            }) {
                                Image(systemName: "plus")
                                    .padding(8)
                                    .background(Circle().fill(Color.gray.opacity(0.2)))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal)

                        // Image Grid
                        GridView(images: generateMockImages())

                        // Address and Hours
                        VStack(alignment: .leading, spacing: 8) {
                            if let openingHours = place.currentOpeningHours?.weekdayText {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Opening Hours:")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    ForEach(openingHours, id: \.self) { hour in
                                        Text(hour)
                                            .font(.subheadline)
                                            .foregroundColor(.black)
                                    }
                                }
                            } else {
                                Text("Opening hours not available")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
    }

    // Mock image generation (replace with real images from GMSPlace if available)
    func generateMockImages() -> [String] {
        return [
            "https://via.placeholder.com/100",
            "https://via.placeholder.com/100",
            "https://via.placeholder.com/100",
            "https://via.placeholder.com/100",
            "https://via.placeholder.com/100",
            "https://via.placeholder.com/100"
        ]
    }
}

struct GridView: View {
    let images: [String]

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(images, id: \.self) { image in
                if let url = URL(string: image) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipped()
                                .cornerRadius(8)
                        } else if phase.error != nil {
                            Rectangle()
                                .foregroundColor(.gray)
                                .frame(height: 100)
                                .cornerRadius(8)
                        } else {
                            ProgressView()
                                .frame(height: 100)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
}
