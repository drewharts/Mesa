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
    private let clusterRadiusMeters: Double = 150

    /// Initializes with a NearbyPlacesService for fetching places per cluster.
    init(nearbyPlacesService: NearbyPlacesService = NearbyPlacesService()) {
        self.nearbyPlacesService = nearbyPlacesService
    }

    // MARK: - Clustering

    /// Clusters photos by GPS proximity using a greedy algorithm (~150m radius).
    func clusterPhotos(photoDataPairs: [(UIImage, Data)]) {
        isProcessing = true
        clusters = []
        unassignedPhotoIndices = []

        var tempClusters: [MutableCluster] = []

        for (index, (_, data)) in photoDataPairs.enumerated() {
            guard let coords = PhotoImportViewModel.extractGPSCoordinates(from: data) else {
                unassignedPhotoIndices.append(index)
                continue
            }

            let assignedToExisting = assignToExistingCluster(
                index: index,
                coords: coords,
                clusters: &tempClusters
            )

            if !assignedToExisting {
                tempClusters.append(MutableCluster(
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    photoIndices: [index]
                ))
            }
        }

        // Recalculate cluster centers as average of member coordinates and convert
        clusters = tempClusters.map { mutable in
            PhotoLocationCluster(
                latitude: mutable.latitude,
                longitude: mutable.longitude,
                photoIndices: mutable.photoIndices,
                nearbyPlaces: [],
                selectedPlace: nil,
                resolvedPlace: nil,
                isLoadingPlaces: false,
                searchRadiusUsed: 50,
                isReviewed: false
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

        await withTaskGroup(of: (Int, [NearbyPlaceFeature], Int).self) { group in
            for (offset, cluster) in clusters.enumerated() {
                let lat = cluster.latitude
                let lng = cluster.longitude
                let idx = offset
                group.addTask {
                    let (places, radius) = await self.fetchNearbyPlacesForCoordinate(
                        latitude: lat, longitude: lng
                    )
                    return (idx, places, radius)
                }
            }
            for await (index, places, radius) in group {
                guard index < clusters.count else { continue }
                clusters[index].nearbyPlaces = places
                clusters[index].searchRadiusUsed = radius
                clusters[index].isLoadingPlaces = false
            }
        }
    }

    /// Fetches nearby places for a single cluster with expanding radius (50→250→1000m).
    func fetchNearbyPlacesForCluster(_ clusterId: UUID) async {
        guard let index = clusters.firstIndex(where: { $0.id == clusterId }) else { return }
        clusters[index].isLoadingPlaces = true

        let (places, radius) = await fetchNearbyPlacesForCoordinate(
            latitude: clusters[index].latitude,
            longitude: clusters[index].longitude
        )

        clusters[index].nearbyPlaces = places
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

    /// Temporary mutable struct used during clustering algorithm.
    private struct MutableCluster {
        var latitude: Double
        var longitude: Double
        var photoIndices: [Int]
        var coordSum: (lat: Double, lng: Double)

        init(latitude: Double, longitude: Double, photoIndices: [Int]) {
            self.latitude = latitude
            self.longitude = longitude
            self.photoIndices = photoIndices
            self.coordSum = (lat: latitude, lng: longitude)
        }

        /// Recalculates the cluster center based on a newly added coordinate.
        mutating func addCoordinate(lat: Double, lng: Double, index: Int) {
            photoIndices.append(index)
            coordSum.lat += lat
            coordSum.lng += lng
            let count = Double(photoIndices.count)
            latitude = coordSum.lat / count
            longitude = coordSum.lng / count
        }
    }

    /// Tries to assign a photo to an existing cluster within the proximity radius.
    private func assignToExistingCluster(
        index: Int,
        coords: (latitude: Double, longitude: Double),
        clusters: inout [MutableCluster]
    ) -> Bool {
        for i in clusters.indices {
            let distance = haversineDistance(
                lat1: clusters[i].latitude, lon1: clusters[i].longitude,
                lat2: coords.latitude, lon2: coords.longitude
            )
            if distance <= clusterRadiusMeters {
                clusters[i].addCoordinate(lat: coords.latitude, lng: coords.longitude, index: index)
                return true
            }
        }
        return false
    }

    /// Removes a photo index from whatever cluster or unassigned pool it currently belongs to.
    private func removePhotoFromCurrentLocation(photoIndex: Int) {
        for i in clusters.indices {
            clusters[i].photoIndices.removeAll { $0 == photoIndex }
        }
        unassignedPhotoIndices.removeAll { $0 == photoIndex }
    }

    /// Fetches nearby places with expanding radius search (50 → 250 → 1000m).
    private func fetchNearbyPlacesForCoordinate(
        latitude: Double,
        longitude: Double
    ) async -> ([NearbyPlaceFeature], Int) {
        let radii = [50, 250, 1000]
        for radius in radii {
            do {
                let response = try await nearbyPlacesService.fetchNearbyPlaces(
                    latitude: latitude,
                    longitude: longitude,
                    radiusMeters: radius
                )
                if !response.features.isEmpty {
                    return (response.features, radius)
                }
            } catch {
                print("❌ Failed to fetch nearby places at radius \(radius)m: \(error)")
            }
        }
        return ([], 1000)
    }

    /// Calculates the distance in meters between two coordinates using the Haversine formula.
    private func haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let earthRadius = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
