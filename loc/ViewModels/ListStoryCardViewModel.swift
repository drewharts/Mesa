//
//  ListStoryCardViewModel.swift
//  loc
//
//  ViewModel for generating shareable list story cards with photo collage and map.
//

import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import CoreLocation

/// Sharing destination options for story cards.
enum StoryShareDestination {
    case instagram
    case general
}

/// ViewModel for generating shareable Instagram Story-style list cards.
@MainActor
class ListStoryCardViewModel: ObservableObject {
    @Published var isGenerating: Bool = false
    @Published var generatedImage: UIImage?
    @Published var error: String?
    @Published var showShareOptions: Bool = false
    @Published var showLinkCopiedInstruction: Bool = false

    // Photo selection (for advanced flow)
    @Published var availablePhotos: [PhotoOption] = []
    @Published var selectedPhotoIndex: Int = 0
    @Published var showPhotoSelector: Bool = false

    private let imageCacheService = ImageCacheService.shared
    private let imageService = ImageService.shared
    private let externalMetadataCache = ExternalMetadataCache.shared
    private let instagramService = InstagramStoriesService()
    private let mapSnapshotService = MapSnapshotService()
    private let placeService = SupabasePlaceService.shared

    private let universalLinkHost = MesaBackendConfig.universalLinkHost

    private let storyWidth: CGFloat = 1080
    private let storyHeight: CGFloat = 1920

    /// Checks if Instagram is available for direct sharing.
    var canShareToInstagram: Bool {
        instagramService.isInstagramInstalled
    }

    // MARK: - Quick Share (auto-picks best photos, no selector)

    /// Generates a share card automatically and presents the system share sheet.
    func quickShare(
        list: LightweightPlaceList,
        places: [LightweightPlace],
        userId: String,
        shareService: PlaceShareService
    ) async {
        isGenerating = true
        error = nil

        do {
            let cardImage = try await generateCard(
                list: list,
                places: places,
                userId: userId,
                includeQRCode: true
            )

            generatedImage = cardImage
            let shareText = "Check out my list \"\(list.name)\" on Mesa!"
            shareService.shareImage(cardImage, with: shareText)
            uploadListCover(listId: list.list_id, image: cardImage)
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - Instagram Share

    /// Generates and shares a story card to Instagram Stories with link.
    func shareToInstagram(
        list: LightweightPlaceList,
        places: [LightweightPlace],
        userId: String
    ) async {
        isGenerating = true
        error = nil

        do {
            let cardImage = try await generateCard(
                list: list,
                places: places,
                userId: userId,
                includeQRCode: false,
                overridePhotoURL: selectedPhotoURL
            )

            let universalLink = generateUniversalLink(for: list, userId: userId)
            if let link = universalLink {
                UIPasteboard.general.string = link.absoluteString
            }

            let success = instagramService.shareToInstagramStories(
                backgroundImage: cardImage,
                contentURL: universalLink
            )

            if !success {
                throw StoryCardError.instagramNotAvailable
            }

            showLinkCopiedInstruction = true
            uploadListCover(listId: list.list_id, image: cardImage)
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - General Share (with photo selector)

    /// Generates and shares a story card via system share sheet with QR code.
    func shareGeneral(
        list: LightweightPlaceList,
        places: [LightweightPlace],
        userId: String,
        shareService: PlaceShareService
    ) async {
        isGenerating = true
        error = nil

        do {
            let cardImage = try await generateCard(
                list: list,
                places: places,
                userId: userId,
                includeQRCode: true,
                overridePhotoURL: selectedPhotoURL
            )

            generatedImage = cardImage
            let shareText = "Check out my list \"\(list.name)\" on Mesa!"
            shareService.shareImage(cardImage, with: shareText)
            uploadListCover(listId: list.list_id, image: cardImage)
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - Photo Selection

    /// Prepares photo options for the user to choose from.
    func preparePhotoOptions(places: [LightweightPlace]) async {
        var photos: [PhotoOption] = []

        for place in places {
            if let contentUrl = place.content_url {
                if let thumbnailUrl = externalMetadataCache.getCachedThumbnailUrl(for: contentUrl) {
                    photos.append(PhotoOption(url: thumbnailUrl, placeName: place.name, source: .externalVideo))
                } else if let thumbnailUrl = await externalMetadataCache.getThumbnailUrl(for: contentUrl) {
                    photos.append(PhotoOption(url: thumbnailUrl, placeName: place.name, source: .externalVideo))
                }
            }

            if let reviewPhoto = place.latest_review_photo {
                photos.append(PhotoOption(url: reviewPhoto, placeName: place.name, source: .review))
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

    // MARK: - Card Generation (Core)

    /// Generates the complete card image with photo collage, map, and branding.
    private func generateCard(
        list: LightweightPlaceList,
        places: [LightweightPlace],
        userId: String,
        includeQRCode: Bool,
        overridePhotoURL: URL? = nil
    ) async throws -> UIImage {
        let universalLink = generateUniversalLink(for: list, userId: userId)
        let qrCodeImage = includeQRCode ? generateQRCode(from: universalLink) : nil

        let mapImage = await generateMapSnapshot(placeIds: places.map { $0.place_id })
        let placePhotos = await loadPlacePhotos(from: places, overrideURL: overridePhotoURL)
        let ownerPhoto = await loadOwnerPhoto(url: list.owner_photo_url)

        let cardData = buildCardData(list: list, userId: userId, universalLink: universalLink)

        guard let image = renderCard(
            data: cardData, placePhotos: placePhotos,
            mapImage: mapImage, qrCodeImage: qrCodeImage, ownerPhoto: ownerPhoto
        ) else {
            throw StoryCardError.renderFailed
        }

        return image
    }

    /// Generates a map snapshot image from place coordinates.
    private func generateMapSnapshot(placeIds: [String]) async -> UIImage? {
        let coordinates = (try? await placeService.fetchPlaceCoordinates(placeIds: placeIds)) ?? [:]
        let mapSize = CGSize(width: storyWidth - 56, height: 200 * 3)
        return await mapSnapshotService.generateSnapshot(coordinates: Array(coordinates.values), size: mapSize)
    }

    /// Builds the card data model from a list and user info.
    private func buildCardData(list: LightweightPlaceList, userId: String, universalLink: URL?) -> ListStoryCardData {
        ListStoryCardData(
            listName: list.name,
            placeCount: list.place_count,
            ownerName: list.owner_name ?? "Mesa User",
            ownerPhotoURL: list.owner_photo_url != nil ? URL(string: list.owner_photo_url!) : nil,
            city: list.city,
            backgroundImageURL: nil,
            listUniversalLink: universalLink
        )
    }

    /// Loads up to 4 place photos for the collage.
    private func loadPlacePhotos(from places: [LightweightPlace], overrideURL: URL?) async -> [UIImage] {
        var photoURLs: [String] = []

        if let override = overrideURL {
            photoURLs.append(override.absoluteString)
        }

        for place in places {
            if photoURLs.count >= 4 { break }
            if let photo = place.latest_review_photo, !photoURLs.contains(photo) {
                photoURLs.append(photo)
            } else if let thumb = place.thumbnail_url, !photoURLs.contains(thumb) {
                photoURLs.append(thumb)
            }
        }

        let loaded = await imageCacheService.loadImages(from: Array(photoURLs.prefix(4)))
        return photoURLs.prefix(4).compactMap { loaded[$0] }
    }

    /// Loads the list owner's profile photo.
    private func loadOwnerPhoto(url: String?) async -> UIImage? {
        guard let urlStr = url, let url = URL(string: urlStr) else { return nil }
        let loaded = await imageCacheService.loadImages(from: [url.absoluteString])
        return loaded[url.absoluteString]
    }

    /// Renders the card view to a UIImage using ImageRenderer.
    private func renderCard(
        data: ListStoryCardData,
        placePhotos: [UIImage],
        mapImage: UIImage?,
        qrCodeImage: UIImage?,
        ownerPhoto: UIImage?
    ) -> UIImage? {
        let cardView = ListShareCardView(
            data: data,
            placePhotos: placePhotos,
            mapImage: mapImage,
            qrCodeImage: qrCodeImage,
            ownerPhoto: ownerPhoto
        )
        .frame(width: storyWidth, height: storyHeight)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    // MARK: - Helpers

    /// Generates a universal link URL for the list.
    private func generateUniversalLink(for list: LightweightPlaceList, userId: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = universalLinkHost
        components.path = "/list/\(list.list_id)"
        components.queryItems = [
            URLQueryItem(name: "name", value: list.name),
            URLQueryItem(name: "city", value: list.city ?? ""),
            URLQueryItem(name: "userId", value: userId)
        ]
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
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Uploads the card image as a list cover for rich link previews.
    private func uploadListCover(listId: String, image: UIImage) {
        Task {
            do {
                _ = try await imageService.uploadListCoverImage(listId: listId, image: image)
            } catch {
                print("⚠️ [ListStoryCardViewModel] Failed to upload list cover: \(error.localizedDescription)")
            }
        }
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
        case .renderFailed: return "Failed to render story card image"
        case .instagramNotAvailable: return "Instagram is not installed"
        }
    }
}
