//  PhotoClusteringViewModel.swift
//  loc
//
//  Child ViewModel for clustering photos by GPS proximity and managing per-cluster state.

import SwiftUI
import Combine

@MainActor
class PhotoClusteringViewModel: ObservableObject {
    @Published var clusters: [PhotoLocationCluster] = []
    @Published var unassignedPhotoIndices: [Int] = []
    @Published var isProcessing: Bool = false

    private let nearbyPlacesService: NearbyPlacesService

    /// Initializes with a NearbyPlacesService for fetching places per cluster.
    init(nearbyPlacesService: NearbyPlacesService = NearbyPlacesService()) {
        self.nearbyPlacesService = nearbyPlacesService
    }

    // MARK: - Clustering

    /// Clusters photos into visits by GPS proximity (~60m) and capture time (45 min gap).
    func clusterPhotos(photoDataPairs: [(UIImage, Data)]) {
        isProcessing = true
        let samples = photoDataPairs.map { PhotoSample.from(imageData: $0.1) }
        let result = PhotoClusterBuilder.build(samples: samples)
        unassignedPhotoIndices = result.unassigned
        clusters = result.clusters.map { draft in
            PhotoLocationCluster(
                latitude: draft.latitude,
                longitude: draft.longitude,
                photoIndices: draft.photoIndices,
                nearbyPlaces: [],
                selectedPlace: nil,
                resolvedPlace: nil,
                isLoadingPlaces: false,
                searchRadiusUsed: PlaceCandidateRanker.searchRadii(bestAccuracyMeters: draft.bestAccuracyMeters)[0],
                isReviewed: false,
                bestAccuracyMeters: draft.bestAccuracyMeters,
                capturedAt: draft.firstCapturedAt,
                utcOffsetSeconds: draft.utcOffsetSeconds
            )
        }
        isProcessing = false
    }

    // MARK: - Nearby Places

    /// Fetches nearby places for all clusters in parallel.
    func fetchAllNearbyPlaces() async {
        // Mark all clusters as loading before starting fetches
        for i in clusters.indices {
            clusters[i].isLoadingPlaces = true
        }

        let snapshot = clusters
        await withTaskGroup(of: (UUID, [NearbyPlaceFeature], Int).self) { group in
            for cluster in snapshot {
                group.addTask {
                    let (places, radius) = await self.searchPlaces(for: cluster)
                    return (cluster.id, places, radius)
                }
            }
            for await (clusterId, places, radius) in group {
                applyResults(places: places, radius: radius, toCluster: clusterId)
            }
        }
    }

    /// Fetches nearby places for a single cluster with expanding radius (accuracy-aware first step, then 150m, capped at 300m).
    func fetchNearbyPlacesForCluster(_ clusterId: UUID) async {
        guard let index = clusters.firstIndex(where: { $0.id == clusterId }) else { return }
        clusters[index].isLoadingPlaces = true

        let (places, radius) = await searchPlaces(for: clusters[index])
        applyResults(places: places, radius: radius, toCluster: clusterId)
    }

    /// Ranks fetched places for a cluster and stores them with the radius used.
    private func applyResults(places: [NearbyPlaceFeature], radius: Int, toCluster clusterId: UUID) {
        guard let index = clusters.firstIndex(where: { $0.id == clusterId }) else { return }
        let ranked = PlaceCandidateRanker.rank(
            places,
            centerLatitude: clusters[index].latitude,
            centerLongitude: clusters[index].longitude,
            capturedAt: clusters[index].capturedAt,
            utcOffsetSeconds: clusters[index].utcOffsetSeconds
        )
        clusters[index].nearbyPlaces = ranked.places
        clusters[index].hasConfidentPick = ranked.hasConfidentPick
        clusters[index].searchRadiusUsed = radius
        clusters[index].isLoadingPlaces = false
    }

    // MARK: - Photo Reassignment

    /// Moves a photo from its current cluster (or unassigned) to the target cluster.
    func movePhoto(photoIndex: Int, toClusterId: UUID) {
        removePhotoFromCurrentLocation(photoIndex: photoIndex)

        guard let targetIdx = clusters.firstIndex(where: { $0.id == toClusterId }) else { return }
        clusters[targetIdx].photoIndices.append(photoIndex)
    }

    /// Moves a photo from its cluster back to the unassigned pool.
    func movePhotoToUnassigned(photoIndex: Int) {
        removePhotoFromCurrentLocation(photoIndex: photoIndex)
        unassignedPhotoIndices.append(photoIndex)
    }

    /// Resets all clustering state.
    func reset() {
        clusters = []
        unassignedPhotoIndices = []
        isProcessing = false
    }

    /// Marks a cluster as reviewed after the user completes the review flow.
    func markClusterReviewed(_ clusterId: UUID) {
        guard let index = clusters.firstIndex(where: { $0.id == clusterId }) else { return }
        clusters[index].isReviewed = true
    }

    /// Whether all clusters with photos have been reviewed.
    var allClustersReviewed: Bool {
        clusters.allSatisfy { $0.photoIndices.isEmpty || $0.isReviewed }
    }

    /// The count of clusters that have been reviewed.
    var reviewedCount: Int {
        clusters.filter { $0.isReviewed }.count
    }

    /// The count of clusters that have photos (reviewable).
    var reviewableCount: Int {
        clusters.filter { !$0.photoIndices.isEmpty }.count
    }

    // MARK: - Private Helpers

    /// Removes a photo index from whatever cluster or unassigned pool it currently belongs to.
    private func removePhotoFromCurrentLocation(photoIndex: Int) {
        for i in clusters.indices {
            clusters[i].photoIndices.removeAll { $0 == photoIndex }
        }
        unassignedPhotoIndices.removeAll { $0 == photoIndex }
    }

    /// Fetches nearby places for a cluster with expanding radius; returns nothing when no place is within the last radius.
    private func searchPlaces(for cluster: PhotoLocationCluster) async -> ([NearbyPlaceFeature], Int) {
        let radii = PlaceCandidateRanker.searchRadii(bestAccuracyMeters: cluster.bestAccuracyMeters)
        for radius in radii {
            do {
                let response = try await nearbyPlacesService.fetchNearbyPlaces(
                    latitude: cluster.latitude,
                    longitude: cluster.longitude,
                    radiusMeters: radius
                )
                if !response.features.isEmpty {
                    return (response.features, radius)
                }
            } catch {
                print("❌ Failed to fetch nearby places at radius \(radius)m: \(error)")
            }
        }
        return ([], radii.last ?? 300)
    }
}
