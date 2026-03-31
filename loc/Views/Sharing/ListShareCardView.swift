//
//  ListShareCardView.swift
//  loc
//
//  Shareable story card for lists — rendered to UIImage for Instagram Stories and iMessage.
//

import SwiftUI

/// Instagram Story-format card showcasing a list with photo collage, map, and creator info.
struct ListShareCardView: View {
    let data: ListStoryCardData
    let placePhotos: [UIImage]
    let mapImage: UIImage?
    let qrCodeImage: UIImage?
    let ownerPhoto: UIImage?

    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1920

    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 0) {
                photoCollageSection
                Spacer(minLength: 0)
                infoSection
                brandingSection
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipped()
    }

    // MARK: - Background

    /// Full-bleed dark gradient behind all content.
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(white: 0.08), Color(white: 0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Photo Collage

    /// Renders a 2×2 photo grid from list place photos with rounded corners.
    private var photoCollageSection: some View {
        Group {
            if placePhotos.isEmpty {
                emptyPhotoFallback
            } else {
                photoGrid
            }
        }
        .frame(height: cardHeight * 0.48)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 28)
        .padding(.top, 60)
    }

    /// Grid layout adapting to available photo count.
    private var photoGrid: some View {
        let photos = Array(placePhotos.prefix(4))
        return Group {
            switch photos.count {
            case 1:
                singlePhoto(photos[0])
            case 2:
                HStack(spacing: 4) {
                    singlePhoto(photos[0])
                    singlePhoto(photos[1])
                }
            case 3:
                HStack(spacing: 4) {
                    singlePhoto(photos[0])
                    VStack(spacing: 4) {
                        singlePhoto(photos[1])
                        singlePhoto(photos[2])
                    }
                }
            default:
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        singlePhoto(photos[0])
                        singlePhoto(photos[1])
                    }
                    HStack(spacing: 4) {
                        singlePhoto(photos[2])
                        singlePhoto(photos[3])
                    }
                }
            }
        }
    }

    /// Renders a single photo filling its container.
    private func singlePhoto(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .clipped()
    }

    /// Gradient placeholder when no place photos are available.
    private var emptyPhotoFallback: some View {
        LinearGradient(
            colors: [Color.mesaAccent, Color.mesaAccentDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.3))
        )
    }

    // MARK: - Map Section

    /// Small rounded map snapshot showing pin locations.
    @ViewBuilder
    private var mapSection: some View {
        if let map = mapImage {
            Image(uiImage: map)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 28)
        }
    }

    // MARK: - Info Section

    /// Displays list name, creator info, and metadata.
    private var infoSection: some View {
        VStack(spacing: 28) {
            mapSection

            Text(data.listName)
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 40)

            creatorRow

            metaRow
        }
        .padding(.bottom, 40)
    }

    /// Shows creator profile photo and name.
    private var creatorRow: some View {
        HStack(spacing: 14) {
            Group {
                if let photo = ownerPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Color.mesaAccent)
                        .overlay(
                            Text(String(data.ownerName.prefix(1)).uppercased())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            Text(data.ownerName)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    /// Shows place count and city.
    private var metaRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.mesaAccent)

            Text("\(data.placeCount) place\(data.placeCount == 1 ? "" : "s")")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            if let city = data.city, !city.isEmpty {
                Text("·")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.4))
                Text(city)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Branding

    /// Mesa branding and optional QR code at the bottom.
    private var brandingSection: some View {
        VStack(spacing: 20) {
            if let qr = qrCodeImage {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(14)
            }

            Text("MESA")
                .font(.system(size: 32, weight: .bold))
                .tracking(8)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.bottom, 70)
    }
}
