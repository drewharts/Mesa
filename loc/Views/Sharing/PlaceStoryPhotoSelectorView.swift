//
//  PlaceStoryPhotoSelectorView.swift
//  loc
//

import SwiftUI

/// View for selecting which photo to use in the place story card.
struct PlaceStoryPhotoSelectorView: View {
    @ObservedObject var viewModel: PlaceStoryCardViewModel
    let onShareInstagram: () -> Void
    let onShareGeneral: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.availablePhotos.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }

                Divider()

                shareButtons
            }
            .navigationTitle("Choose Cover Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// Empty state when no photos are available for the place.
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No photos available")
                .font(.headline)
                .foregroundColor(.gray)
            Text("A gradient background will be used")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// Grid of available photo options.
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(
                    Array(viewModel.availablePhotos.enumerated()),
                    id: \.element.id
                ) { index, photo in
                    PlacePhotoOptionCell(
                        photo: photo,
                        isSelected: index == viewModel.selectedPhotoIndex,
                        onSelect: {
                            viewModel.selectedPhotoIndex = index
                        }
                    )
                }
            }
            .padding(16)
        }
    }

    /// Share action buttons at the bottom.
    private var shareButtons: some View {
        VStack(spacing: 12) {
            if viewModel.canShareToInstagram {
                instagramButton
            }

            generalShareButton
        }
        .padding(16)
        .disabled(viewModel.isGenerating)
        .overlay {
            if viewModel.isGenerating {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
    }

    /// Button to share directly to Instagram Stories.
    private var instagramButton: some View {
        Button {
            dismiss()
            onShareInstagram()
        } label: {
            HStack {
                Image(systemName: "camera.circle.fill")
                Text("Share to Instagram Stories")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [.purple, .pink, .orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }

    /// Button to share via system share sheet.
    private var generalShareButton: some View {
        Button {
            dismiss()
            onShareGeneral()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Image")
            }
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemGray5))
            .cornerRadius(12)
        }
    }
}

/// Individual photo option cell for the place story card selector.
private struct PlacePhotoOptionCell: View {
    let photo: PhotoOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                photoImage
                sourceBadge
                selectionOverlay
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Async-loaded photo thumbnail.
    private var photoImage: some View {
        AsyncImage(url: URL(string: photo.url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            case .empty:
                ProgressView()
            @unknown default:
                placeholder
            }
        }
        .frame(height: 120)
        .clipped()
        .cornerRadius(8)
    }

    /// Source type badge showing origin of the photo.
    private var sourceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: sourceIconName)
                .font(.system(size: 10))
            Text(photo.placeName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(4)
        .padding(6)
    }

    /// Selection checkmark and border overlay.
    @ViewBuilder
    private var selectionOverlay: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 3)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .background(Circle().fill(.white))
                .position(x: 20, y: 20)
        }
    }

    /// Returns the appropriate SF Symbol name for the photo source type.
    private var sourceIconName: String {
        switch photo.source {
        case .externalVideo:
            return "play.rectangle.fill"
        case .review, .post:
            return "camera.fill"
        }
    }

    /// Placeholder view for failed image loads.
    private var placeholder: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            )
    }
}
