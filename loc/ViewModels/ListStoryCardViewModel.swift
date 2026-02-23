//
//  ListStoryCardViewModel.swift
//  loc
//
//  Created by Claude on 1/30/25.
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import CoreLocation

/// Sharing destination options for story cards.
enum StoryShareDestination {
    case instagram  // Direct to Instagram Stories with link sticker
    case general    // System share sheet with QR code
}

/// ViewModel for generating shareable Instagram Story-style list cards.
@MainActor
class ListStoryCardViewModel: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var generatedImage: UIImage?
    @Published var error: String?
    @Published var showShareOptions: Bool = false
    @Published var showLinkCopiedInstruction: Bool = false

    // Photo selection
    @Published var availablePhotos: [PhotoOption] = []
    @Published var selectedPhotoIndex: Int = 0
    @Published var showPhotoSelector: Bool = false

    private let imageCacheService = ImageCacheService.shared
    private let imageService = ImageService.shared
    private let externalMetadataCache = ExternalMetadataCache.shared
    private let instagramService = InstagramStoriesService()
    private let mapSnapshotService = MapSnapshotService()
    private let placeService = SupabasePlaceService.shared

    // Universal link host for QR code generation
    private let universalLinkHost = MesaBackendConfig.universalLinkHost

    // Instagram Story dimensions (9:16 aspect ratio)
    private let storyWidth: CGFloat = 1080
    private let storyHeight: CGFloat = 1920

    /// Checks if Instagram is available for direct sharing.
    var canShareToInstagram: Bool {
        instagramService.isInstagramInstalled
    }

    /// Prepares photo options for the user to choose from.
    func preparePhotoOptions(places: [LightweightPlace]) async {
        var photos: [PhotoOption] = []

        for place in places {
            // Check external video thumbnails
            if let contentUrl = place.content_url {
                if let thumbnailUrl = externalMetadataCache.getCachedThumbnailUrl(for: contentUrl) {
                    photos.append(PhotoOption(
                        url: thumbnailUrl,
                        placeName: place.name,
                        source: .externalVideo
                    ))
                } else if let thumbnailUrl = await externalMetadataCache.getThumbnailUrl(for: contentUrl) {
                    photos.append(PhotoOption(
                        url: thumbnailUrl,
                        placeName: place.name,
                        source: .externalVideo
                    ))
                }
            }

            // Check review photos
            if let reviewPhoto = place.latest_review_photo {
                photos.append(PhotoOption(
                    url: reviewPhoto,
                    placeName: place.name,
                    source: .review
                ))
            }
        }

        availablePhotos = photos
        selectedPhotoIndex = 0
    }

    /// Gets the currently selected photo URL.
    var selectedPhotoURL: URL? {
        guard selectedPhotoIndex < availablePhotos.count else { return nil }
        return URL(string: availablePhotos[selectedPhotoIndex].url)
    }

    /// Generates and shares a story card to Instagram Stories with link.
    func shareToInstagram(
        list: LightweightPlaceList,
        places: [LightweightPlace],
        userId: String
    ) async {
        isGenerating = true
        error = nil

        do {
            // 1. Get selected background photo URL
            let backgroundURL: URL?
            if let selected = selectedPhotoURL {
                backgroundURL = selected
            } else {
                backgroundURL = await findBackgroundPhotoURL(from: places)
            }

            // 2. Generate universal link for the list
            let universalLink = generateUniversalLink(for: list, userId: userId)

            // 3. Fetch place coordinates and generate map snapshot
            let placeIds = places.map { $0.place_id }
            let coordinates = try await placeService.fetchPlaceCoordinates(placeIds: placeIds)
            let coordArray = Array(coordinates.values)

            let mapSize = CGSize(width: storyWidth, height: storyHeight / 2)
            let mapImage = await mapSnapshotService.generateSnapshot(
                coordinates: coordArray,
                size: mapSize
            )

            // 4. Load background image
            let backgroundImage = await loadBackgroundImage(url: backgroundURL)

            // 5. Generate the story card image
            let cardData = ListStoryCardData(
                listName: list.name,
                placeCount: list.place_count,
                ownerName: "",
                ownerPhotoURL: nil,
                backgroundImageURL: backgroundURL,
                listUniversalLink: universalLink
            )

            guard let storyImage = renderStoryCard(
                data: cardData,
                backgroundImage: backgroundImage,
                mapImage: mapImage,
                qrCodeImage: nil
            ) else {
                throw StoryCardError.renderFailed
            }

            // 6. Copy link to clipboard so user can paste it as a link sticker
            if let link = universalLink {
                UIPasteboard.general.string = link.absoluteString
            }

            // 7. Share to Instagram Stories
            let success = instagramService.shareToInstagramStories(
                backgroundImage: storyImage,
                contentURL: universalLink
            )

            if !success {
                throw StoryCardError.instagramNotAvailable
            }

            // 8. Show instruction to add link sticker
            showLinkCopiedInstruction = true

            // 9. Fire-and-forget: upload story card as list cover for rich link previews
            uploadListCover(listId: list.list_id, image: storyImage)

        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    /// Generates and shares a story card via system share sheet (with QR code).
    func shareGeneral(
        list: LightweightPlaceList,
        places: [LightweightPlace],
        userId: String,
        shareService: PlaceShareService
    ) async {
        isGenerating = true
        error = nil

        do {
            // 1. Get selected background photo URL
            let backgroundURL: URL?
            if let selected = selectedPhotoURL {
                backgroundURL = selected
            } else {
                backgroundURL = await findBackgroundPhotoURL(from: places)
            }

            // 2. Generate universal link for the list
            let universalLink = generateUniversalLink(for: list, userId: userId)

            // 3. Generate QR code image
            let qrCodeImage = generateQRCode(from: universalLink)

            // 4. Fetch place coordinates and generate map snapshot
            let placeIds = places.map { $0.place_id }
            let coordinates = try await placeService.fetchPlaceCoordinates(placeIds: placeIds)
            let coordArray = Array(coordinates.values)

            let mapSize = CGSize(width: storyWidth, height: storyHeight / 2)
            let mapImage = await mapSnapshotService.generateSnapshot(
                coordinates: coordArray,
                size: mapSize
            )

            // 5. Load background image
            let backgroundImage = await loadBackgroundImage(url: backgroundURL)

            // 6. Generate the story card image with QR code
            let cardData = ListStoryCardData(
                listName: list.name,
                placeCount: list.place_count,
                ownerName: "",
                ownerPhotoURL: nil,
                backgroundImageURL: backgroundURL,
                listUniversalLink: universalLink
            )

            guard let storyImage = renderStoryCard(
                data: cardData,
                backgroundImage: backgroundImage,
                mapImage: mapImage,
                qrCodeImage: qrCodeImage
            ) else {
                throw StoryCardError.renderFailed
            }

            generatedImage = storyImage

            // 7. Share the image with the universal link
            let shareText = "Check out my list \"\(list.name)\" on Mesa!"
            shareService.shareImage(storyImage, with: shareText)

            // 8. Fire-and-forget: upload story card as list cover for rich link previews
            uploadListCover(listId: list.list_id, image: storyImage)

        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    /// Generates a universal link URL for the list.
    private func generateUniversalLink(for list: LightweightPlaceList, userId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = universalLinkHost
        components.path = "/list/\(list.list_id)"

        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: list.name))
        queryItems.append(URLQueryItem(name: "city", value: list.city ?? ""))
        queryItems.append(URLQueryItem(name: "userId", value: userId))

        components.queryItems = queryItems
        return components.url
    }

    /// Generates a QR code image from a URL.
    private func generateQRCode(from url: URL?) -> UIImage? {
        guard let url = url else { return nil }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up the QR code for better resolution
        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Finds the best background photo URL from the list's places.
    private func findBackgroundPhotoURL(from places: [LightweightPlace]) async -> URL? {
        // Priority 1: External video thumbnail (cached)
        for place in places {
            if let contentUrl = place.content_url {
                // Try cached thumbnail first (synchronous)
                if let thumbnailUrl = externalMetadataCache.getCachedThumbnailUrl(for: contentUrl),
                   let url = URL(string: thumbnailUrl) {
                    return url
                }

                // Fetch if not cached
                if let thumbnailUrl = await externalMetadataCache.getThumbnailUrl(for: contentUrl),
                   let url = URL(string: thumbnailUrl) {
                    return url
                }
            }
        }

        // Priority 2: Review photo
        for place in places {
            if let reviewPhoto = place.latest_review_photo,
               let url = URL(string: reviewPhoto) {
                return url
            }
        }

        // No photo found - will use fallback gradient
        return nil
    }

    /// Loads the background image from URL.
    private func loadBackgroundImage(url: URL?) async -> UIImage? {
        guard let url = url else { return nil }

        let loadedImages = await imageCacheService.loadImages(from: [url.absoluteString])
        return loadedImages[url.absoluteString]
    }

    /// Uploads the story card image as a list cover for rich link previews (fire-and-forget).
    private func uploadListCover(listId: String, image: UIImage) {
        Task {
            do {
                _ = try await imageService.uploadListCoverImage(listId: listId, image: image)
            } catch {
                print("⚠️ [ListStoryCardViewModel] Failed to upload list cover: \(error.localizedDescription)")
            }
        }
    }

    /// Renders the story card view to a UIImage using ImageRenderer.
    private func renderStoryCard(
        data: ListStoryCardData,
        backgroundImage: UIImage?,
        mapImage: UIImage?,
        qrCodeImage: UIImage?
    ) -> UIImage? {
        // Pre-load asset catalog images as UIImage for ImageRenderer compatibility
        let discoverOnMesaImage = UIImage(named: "DiscoverOnMesa")
        let mesaAppIconImage = UIImage(named: "MesaAppIcon")

        let cardView = ListStoryCardView(
            data: data,
            backgroundImage: backgroundImage,
            mapImage: mapImage,
            qrCodeImage: qrCodeImage,
            discoverOnMesaImage: discoverOnMesaImage,
            mesaAppIconImage: mesaAppIconImage
        )
        .frame(width: storyWidth, height: storyHeight)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0 // @3x for crisp output

        return renderer.uiImage
    }
}

/// Represents a photo option for the story card.
struct PhotoOption: Identifiable {
    let id = UUID()
    let url: String
    let placeName: String
    let source: PhotoSource

    enum PhotoSource {
        case externalVideo
        case review
        case post
    }
}

/// Errors that can occur during story card generation.
enum StoryCardError: LocalizedError {
    case renderFailed
    case instagramNotAvailable

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Failed to render story card image"
        case .instagramNotAvailable:
            return "Instagram is not installed"
        }
    }
}
