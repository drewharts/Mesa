//
//  ProfileListCard.swift
//  loc
//
//  Shared list card component for profile list sections.
//  Used by both MyProfile and ExternalProfile list views.
//
//  Single Responsibility: Display a list card with photo collage and info.
//

import SwiftUI

/// Configuration for the profile list card.
struct ProfileListCardConfig {
    let isEditable: Bool           // Can show delete context menu
    let showSharedIndicators: Bool // Show shared by/with indicators

    static let myProfile = ProfileListCardConfig(isEditable: true, showSharedIndicators: true)
    static let external = ProfileListCardConfig(isEditable: false, showSharedIndicators: true)
}

/// Shared list card component for profile list displays.
struct ProfileListCard: View {
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]
    let config: ProfileListCardConfig
    let onTap: () -> Void

    private var totalPlaceCount: Int {
        return list.place_count
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                listCardImage
                listCardInfo
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - List Card Image

    private var listCardImage: some View {
        ZStack {
            if let previewPhotos = list.preview_photos, !previewPhotos.isEmpty {
                PreviewPhotoCollage(photoURLs: previewPhotos)
            } else if !places.isEmpty {
                ListPhotoCollage(
                    places: Array(places.prefix(3)),
                    placeColors: $placeColors
                )
            } else {
                emptyListCard
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var emptyListCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24))
                .foregroundColor(.gray.opacity(0.5))

            Text("No places yet")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - List Card Info

    private var listCardInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(list.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)

            if config.showSharedIndicators {
                sharedIndicator
            } else {
                placeCountText
            }
        }
    }

    @ViewBuilder
    private var sharedIndicator: some View {
        if list.isSharedWithMe, let ownerName = list.owner_name {
            SharedByIndicator(
                ownerName: ownerName,
                ownerPhotoUrl: list.owner_photo_url,
                collaboratorPhotos: list.collaborator_photos
            )
        } else {
            SharedWithIndicator(
                collaboratorPhotos: list.collaborator_photos,
                collaboratorCount: list.collaborator_count ?? 0,
                placeCount: totalPlaceCount
            )
        }
    }

    private var placeCountText: some View {
        Text("\(totalPlaceCount) place\(totalPlaceCount == 1 ? "" : "s")")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}
