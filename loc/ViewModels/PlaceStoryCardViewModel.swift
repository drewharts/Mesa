//
//  PlaceStoryCardViewModel.swift
//  loc
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import CoreLocation

/// ViewModel for generating shareable story card images for individual places.
@MainActor
class PlaceStoryCardViewModel: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var generatedImage: UIImage?
    @Published var error: String?
    @Published var showLinkCopiedInstruction: Bool = false

    // Photo selection
    @Published var availablePhotos: [PhotoOption] = []
    @Published var selectedPhotoIndex: Int = 0

    private let imageCacheService = ImageCacheService.shared
    private let instagramService = InstagramStoriesService()
    private let mapSnapshotService = MapSnapshotService()
    private let placeShareService = ServiceContainer.shared.placeShareService
    private let externalMetadataCache = ExternalMetadataCache.shared

    private let universalLinkHost = MesaBackendConfig.universalLinkHost

    // Instagram Story dimensions (9:16 aspect ratio)
    private let storyWidth: CGFloat = 1080
    private let storyHeight: CGFloat = 1920

    /// Checks if Instagram is available for direct sharing.
    var canShareToInstagram: Bool {
        instagramService.isInstagramInstalled
    }

    /// Returns the currently selected photo URL.
    var selectedPhotoURL: URL? {
        guard selectedPhotoIndex < availablePhotos.count else { return nil }
        return URL(string: availablePhotos[selectedPhotoIndex].url)
    }

    // MARK: - Photo Preparation

    /// Collects available photos from posts, place photo URLs, and external video thumbnails.
    func preparePhotoOptions(place: DetailPlace, posts: [PlacePost]) async {
        var photos: [PhotoOption] = []
        collectPostPhotos(from: posts, into: &photos)
        collectPlacePhotos(from: place, into: &photos)
        await collectExternalPhotos(from: posts, into: &photos)
        availablePhotos = photos
        selectedPhotoIndex = 0
    }

    /// Extracts image URLs from post media.
    private func collectPostPhotos(from posts: [PlacePost], into photos: inout [PhotoOption]) {
        for post in posts {
            for imageUrl in post.images {
                photos.append(PhotoOption(
                    url: imageUrl,
                    placeName: post.placeName,
                    source: .post
                ))
            }
        }
    }

    /// Extracts photo URLs from the place's own photo array.
    private func collectPlacePhotos(from place: DetailPlace, into photos: inout [PhotoOption]) {
        guard let photoUrls = place.photoUrls else { return }
        for urlString in photoUrls {
            photos.append(PhotoOption(
                url: urlString,
                placeName: place.name,
                source: .review
            ))
        }
    }

    /// Fetches external video thumbnail URLs from posts that have video links.
    private func collectExternalPhotos(from posts: [PlacePost], into photos: inout [PhotoOption]) async {
        for post in posts {
            for thumbnailUrl in post.videoThumbnailUrls {
                photos.append(PhotoOption(
                    url: thumbnailUrl,
                    placeName: post.placeName,
                    source: .externalVideo
                ))
            }
        }
    }

    // MARK: - Instagram Sharing

    /// Generates and shares a story card to Instagram Stories with a link sticker.
    func shareToInstagram(place: DetailPlace) async {
        isGenerating = true
        error = nil

        do {
            let (backgroundImage, mapImage, universalLink) = try await prepareCardAssets(place: place)

            let cardData = buildCardData(place: place, universalLink: universalLink)

            guard let storyImage = renderStoryCard(
                data: cardData,
                backgroundImage: backgroundImage,
                mapImage: mapImage,
                qrCodeImage: nil
            ) else {
                throw StoryCardError.renderFailed
            }

            copyLinkToClipboard(universalLink)

            let success = instagramService.shareToInstagramStories(
                backgroundImage: storyImage,
                contentURL: universalLink
            )

            if !success {
                throw StoryCardError.instagramNotAvailable
            }

            showLinkCopiedInstruction = true
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - General Sharing

    /// Generates and shares a story card via system share sheet with QR code.
    func shareGeneral(place: DetailPlace) async {
        isGenerating = true
        error = nil

        do {
            let (backgroundImage, mapImage, universalLink) = try await prepareCardAssets(place: place)
            let qrCodeImage = generateQRCode(from: universalLink)

            let cardData = buildCardData(place: place, universalLink: universalLink)

            guard let storyImage = renderStoryCard(
                data: cardData,
                backgroundImage: backgroundImage,
                mapImage: mapImage,
                qrCodeImage: qrCodeImage
            ) else {
                throw StoryCardError.renderFailed
            }

            generatedImage = storyImage

            let shareText = "Check out \"\(place.name)\" on Mesa!"
            placeShareService.shareImage(storyImage, with: shareText)
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - Asset Preparation

    /// Loads background image, generates map snapshot, and builds the universal link.
    private func prepareCardAssets(
        place: DetailPlace
    ) async throws -> (UIImage?, UIImage?, URL?) {
        let backgroundURL = selectedPhotoURL
        let universalLink = generateUniversalLink(for: place)

        let mapImage = await generateMapSnapshot(for: place)
        let backgroundImage = await loadBackgroundImage(url: backgroundURL)

        return (backgroundImage, mapImage, universalLink)
    }

    /// Generates a map snapshot centered on the place's coordinate with neighborhood-level zoom.
    private func generateMapSnapshot(for place: DetailPlace) async -> UIImage? {
        guard let coordinate = place.coordinate else { return nil }
        let mapSize = CGSize(width: storyWidth, height: storyHeight / 2)
        return await mapSnapshotService.generateSnapshot(
            coordinates: [coordinate],
            size: mapSize,
            minimumSpanDelta: 0.15
        )
    }

    /// Loads a background image from a URL using the image cache.
    private func loadBackgroundImage(url: URL?) async -> UIImage? {
        guard let url = url else { return nil }
        let loadedImages = await imageCacheService.loadImages(from: [url.absoluteString])
        return loadedImages[url.absoluteString]
    }

    // MARK: - Data Building

    /// Builds the data model for rendering the story card.
    private func buildCardData(place: DetailPlace, universalLink: URL?) -> PlaceStoryCardData {
        PlaceStoryCardData(
            placeName: place.name,
            address: place.address ?? place.city,
            backgroundImageURL: selectedPhotoURL,
            placeUniversalLink: universalLink
        )
    }

    /// Generates a universal link URL for the place matching PlaceShareService format.
    private func generateUniversalLink(for place: DetailPlace) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = universalLinkHost
        components.path = "/place/\(place.id.uuidString)"

        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: place.name))

        if let address = place.address {
            queryItems.append(URLQueryItem(name: "address", value: address))
        }
        if let city = place.city {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }
        if let lat = place.coordinate?.latitude {
            queryItems.append(URLQueryItem(name: "lat", value: String(lat)))
        }
        if let lng = place.coordinate?.longitude {
            queryItems.append(URLQueryItem(name: "lng", value: String(lng)))
        }

        components.queryItems = queryItems
        return components.url
    }

    // MARK: - Utilities

    /// Generates a QR code image from a URL.
    private func generateQRCode(from url: URL?) -> UIImage? {
        guard let url = url else { return nil }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Copies the universal link to the clipboard for Instagram link sticker usage.
    private func copyLinkToClipboard(_ link: URL?) {
        guard let link = link else { return }
        UIPasteboard.general.string = link.absoluteString
    }

    /// Renders the story card SwiftUI view to a UIImage using ImageRenderer.
    private func renderStoryCard(
        data: PlaceStoryCardData,
        backgroundImage: UIImage?,
        mapImage: UIImage?,
        qrCodeImage: UIImage?
    ) -> UIImage? {
        let mesaAppIconImage = UIImage(named: "MesaAppIcon")

        let cardView = PlaceStoryCardView(
            data: data,
            backgroundImage: backgroundImage,
            mapImage: mapImage,
            qrCodeImage: qrCodeImage,
            mesaAppIconImage: mesaAppIconImage
        )
        .frame(width: storyWidth, height: storyHeight)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0

        return renderer.uiImage
    }
}
