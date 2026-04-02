//
//  ListStoryCardView.swift
//  loc
//
//  Created by Claude on 1/30/25.
//

import SwiftUI
import UIKit

/// Declarative SwiftUI view for rendering an Instagram Story-style list card.
/// Uses pre-loaded UIImages for synchronous rendering with ImageRenderer.
struct ListStoryCardView: View {
    let data: ListStoryCardData
    let backgroundImage: UIImage?
    let mapImage: UIImage?
    let qrCodeImage: UIImage?
    let discoverOnMesaImage: UIImage?
    let mesaAppIconImage: UIImage?

    // Mesa brand colors for fallback gradient
    private let mesaPrimaryColor = Color(red: 0.2, green: 0.6, blue: 0.9)
    private let mesaSecondaryColor = Color(red: 0.1, green: 0.4, blue: 0.7)

    var body: some View {
        VStack(spacing: 0) {
            // Top half: Map with annotations
            mapSection
                .frame(height: 960) // Half of 1920

            // Bottom half: Image with branding (no overlay on photo)
            ZStack {
                bottomBackgroundLayer
                bottomContentLayer
            }
            .frame(height: 960)
        }
    }

    /// Map section showing place locations.
    private var mapSection: some View {
        Group {
            if let map = mapImage {
                Image(uiImage: map)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback if no map available
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Text("Map")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    /// Background layer for bottom section - image or fallback gradient.
    private var bottomBackgroundLayer: some View {
        Group {
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback gradient when no photo available
                LinearGradient(
                    gradient: Gradient(colors: [mesaPrimaryColor, mesaSecondaryColor]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    /// Content layer with logo, list name, and branding.
    private var bottomContentLayer: some View {
        ZStack {
            // Center content (logo, name, count)
            VStack(spacing: 24) {
                // Mesa app icon logo
                Group {
                    if let icon = mesaAppIconImage {
                        Image(uiImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        // Fallback: colored rectangle with "M"
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.blue)
                            .overlay(
                                Text("M")
                                    .font(.system(size: 80, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 32))

                // List name - just shadow, no background
                Text(data.listName)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .shadow(color: .black, radius: 4, x: 0, y: 2)

                // Place count - just shadow, no background
                Text("\(data.placeCount) place\(data.placeCount == 1 ? "" : "s")")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 3, x: 0, y: 1)
            }

            // Bottom branding section - anchored to bottom
            VStack {
                Spacer()
                brandingSection
                    .padding(.bottom, 60)
            }
        }
        .padding(.horizontal, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Bottom branding section with Discover on Mesa image and QR code.
    private var brandingSection: some View {
        VStack(spacing: 24) {
            // QR code for scanning (only for general share)
            if let qrImage = qrCodeImage {
                qrCodeView(image: qrImage)
            }

            // "Discover on MESA" branding - image with text fallback
            discoverOnMesaBranding
        }
    }

    /// Discover on Mesa branding with solid dark background for reliable ImageRenderer export.
    private var discoverOnMesaBranding: some View {
        VStack(spacing: 4) {
            Text("Discover on")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
            Text("MESA")
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.15))
        )
    }

    /// QR code view with rounded corners and white background.
    private func qrCodeView(image: UIImage) -> some View {
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 140, height: 140)
            .padding(12)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ListStoryCardView(
        data: ListStoryCardData(
            listName: "Best Coffee Shops in SF",
            placeCount: 12,
            ownerName: "",
            ownerPhotoURL: nil,
            city: "San Francisco",
            backgroundImageURL: nil,
            listUniversalLink: URL(string: "https://mesa.app/list/123")
        ),
        backgroundImage: nil,
        mapImage: nil,
        qrCodeImage: nil,
        discoverOnMesaImage: UIImage(named: "DiscoverOnMesa"),
        mesaAppIconImage: UIImage(named: "MesaAppIcon")
    )
    .frame(width: 360, height: 640)
}
