//
//  PlaceStoryCardView.swift
//  loc
//

import SwiftUI
import UIKit

/// Declarative SwiftUI view for rendering an Instagram Story-style place card.
/// Uses pre-loaded UIImages for synchronous rendering with ImageRenderer.
struct PlaceStoryCardView: View {
    let data: PlaceStoryCardData
    let backgroundImage: UIImage?
    let mapImage: UIImage?
    let qrCodeImage: UIImage?
    let mesaAppIconImage: UIImage?

    // Mesa brand colors for fallback gradient
    private let mesaPrimaryColor = Color(red: 0.2, green: 0.6, blue: 0.9)
    private let mesaSecondaryColor = Color(red: 0.1, green: 0.4, blue: 0.7)

    var body: some View {
        VStack(spacing: 0) {
            mapSection
                .frame(height: 960)

            ZStack {
                bottomBackgroundLayer
                bottomContentLayer
            }
            .frame(height: 960)
        }
    }

    /// Map section showing the place location with a single pin and logo overlay.
    private var mapSection: some View {
        ZStack(alignment: .bottomLeading) {
            mapBackground
            placeInfoOverlay
                .padding(.leading, 40)
                .padding(.bottom, 40)
        }
    }

    /// Map background image or placeholder.
    private var mapBackground: some View {
        Group {
            if let map = mapImage {
                Image(uiImage: map)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
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

    /// Bottom-left overlay on the map showing app icon, place name, and address.
    private var placeInfoOverlay: some View {
        HStack(spacing: 20) {
            appIconView
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            VStack(alignment: .leading, spacing: 8) {
                Text(data.placeName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black, radius: 4, x: 0, y: 2)

                if let address = data.address {
                    Text(address)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black, radius: 3, x: 0, y: 1)
                }
            }
        }
    }

    /// Background layer for bottom section — photo or fallback gradient.
    private var bottomBackgroundLayer: some View {
        Group {
            if let image = backgroundImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
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

    /// Content layer with optional QR code bottom-center over the photo.
    @ViewBuilder
    private var bottomContentLayer: some View {
        if let qrImage = qrCodeImage {
            VStack {
                Spacer()
                qrCodeView(image: qrImage)
                    .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Mesa app icon with fallback placeholder.
    private var appIconView: some View {
        Group {
            if let icon = mesaAppIconImage {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.blue)
                    .overlay(
                        Text("M")
                            .font(.system(size: 80, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
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
    PlaceStoryCardView(
        data: PlaceStoryCardData(
            placeName: "Joe's Coffee House",
            address: "123 Main St, San Francisco",
            backgroundImageURL: nil,
            placeUniversalLink: URL(string: "https://mesa.app/place/123")
        ),
        backgroundImage: nil,
        mapImage: nil,
        qrCodeImage: nil,
        mesaAppIconImage: UIImage(named: "MesaAppIcon")
    )
    .frame(width: 360, height: 640)
}
