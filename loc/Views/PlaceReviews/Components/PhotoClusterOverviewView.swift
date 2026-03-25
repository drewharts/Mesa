//  PhotoClusterOverviewView.swift
//  loc
//
//  SMART Component: Overview screen showing all photo clusters with map pins and review status.
//  Single Responsibility: Coordinate multi-cluster review flow navigation and photo reassignment.

import SwiftUI

struct PhotoClusterOverviewView: View {
    @ObservedObject var clusteringVM: PhotoClusteringViewModel
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @ObservedObject var profileVM: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var placeVM: DetailPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    @Environment(\.dismiss) private var dismiss

    @State private var activeClusterId: UUID?
    @State private var showPlaceSelectionForCluster: Bool = false
    @State private var showCreatePostForCluster: Bool = false
    @State private var reassignPhotoIndex: Int?
    @State private var showReassignSheet: Bool = false

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    PhotoClusterMapView(clusters: clusteringVM.clusters)
                        .padding(.top, 8)

                    clusterCards
                    unassignedCard
                    doneButton
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Review Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        photoImportVM.clearSelection()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPlaceSelectionForCluster) {
                activeClusterId = nil
            } content: {
                clusterPlaceSelectionSheet
            }
            .onChange(of: photoImportVM.showPostCreation) {
                if photoImportVM.showPostCreation {
                    photoImportVM.showPostCreation = false
                    showPlaceSelectionForCluster = false
                    // Delay to let PlaceSelection sheet dismiss before presenting CreatePost
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreatePostForCluster = true
                    }
                }
            }
            .sheet(isPresented: $showCreatePostForCluster, onDismiss: handlePostDismiss) {
                clusterCreatePostSheet
            }
            .confirmationDialog(
                "Move Photo",
                isPresented: $showReassignSheet,
                titleVisibility: .visible
            ) {
                reassignOptions
            }
        }
    }

    // MARK: - Cluster Cards

    private var clusterCards: some View {
        ForEach(clusteringVM.clusters) { cluster in
            PhotoClusterCardView(
                addressHint: cluster.addressHint,
                photoCount: cluster.photoIndices.count,
                thumbnails: thumbnailsForCluster(cluster),
                isReviewed: cluster.isReviewed,
                isLoading: cluster.isLoadingPlaces,
                onTap: { beginReviewForCluster(cluster) },
                onLongPressThumbnail: { thumbnailOffset in
                    let photoIndex = cluster.photoIndices[thumbnailOffset]
                    reassignPhotoIndex = photoIndex
                    showReassignSheet = true
                }
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Unassigned Card

    @ViewBuilder
    private var unassignedCard: some View {
        if !clusteringVM.unassignedPhotoIndices.isEmpty {
            UnassignedPhotosCard(
                thumbnails: clusteringVM.unassignedPhotoIndices.compactMap { idx in
                    idx < photoImportVM.selectedImages.count ? photoImportVM.selectedImages[idx] : nil
                },
                onTapThumbnail: { thumbnailOffset in
                    let photoIndex = clusteringVM.unassignedPhotoIndices[thumbnailOffset]
                    reassignPhotoIndex = photoIndex
                    showReassignSheet = true
                }
            )
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            photoImportVM.showClusterOverview = false
            photoImportVM.isInPhotoImportFlow = false
            dismiss()
        } label: {
            HStack {
                Text("Done")
                    .fontWeight(.semibold)
                if clusteringVM.reviewableCount > 0 {
                    Text("— \(clusteringVM.reviewedCount) of \(clusteringVM.reviewableCount) reviewed")
                        .fontWeight(.regular)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(clusteringVM.allClustersReviewed ? mesaCharcoal : Color.gray)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .disabled(!clusteringVM.allClustersReviewed)
    }

    // MARK: - Reassignment Dialog

    @ViewBuilder
    private var reassignOptions: some View {
        ForEach(clusteringVM.clusters) { cluster in
            Button(cluster.addressHint) {
                if let photoIndex = reassignPhotoIndex {
                    clusteringVM.movePhoto(photoIndex: photoIndex, toClusterId: cluster.id)
                }
            }
        }
        Button("Move to Unassigned") {
            if let photoIndex = reassignPhotoIndex {
                clusteringVM.movePhotoToUnassigned(photoIndex: photoIndex)
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Cluster Place Selection Sheet

    @ViewBuilder
    private var clusterPlaceSelectionSheet: some View {
        if let clusterId = activeClusterId,
           let cluster = clusteringVM.clusters.first(where: { $0.id == clusterId }) {
            PlaceSelectionView(
                photoImportVM: photoImportVM,
                profileVM: profileVM,
                selectedPlaceVM: selectedPlaceVM,
                detailPlaceVM: placeVM
            )
        }
    }

    // MARK: - Create Post Sheet

    @ViewBuilder
    private var clusterCreatePostSheet: some View {
        if let clusterId = activeClusterId,
           let cluster = clusteringVM.clusters.first(where: { $0.id == clusterId }),
           let resolvedPlace = photoImportVM.resolvedPlace {
            let clusterImages = cluster.photoIndices.compactMap { idx in
                idx < photoImportVM.selectedImages.count ? photoImportVM.selectedImages[idx] : nil
            }
            CreatePostView(
                place: resolvedPlace,
                userId: userSession.currentUserId ?? "",
                profilePhotoUrl: profileVM.user?.profilePhotoURL?.absoluteString ?? "",
                userFirstName: profileVM.user?.firstName ?? "",
                userLastName: profileVM.user?.lastName ?? "",
                preselectedImages: clusterImages,
                onPostSubmitted: { place in
                    handleClusterPostSubmission(clusterId: clusterId, place: place)
                }
            )
            .environmentObject(selectedPlaceVM)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Actions

    /// Begins the review flow for a specific cluster.
    private func beginReviewForCluster(_ cluster: PhotoLocationCluster) {
        guard !cluster.isReviewed else { return }
        guard !cluster.isLoadingPlaces else { return }
        activeClusterId = cluster.id

        // Scope the import VM to this cluster's data
        photoImportVM.detectedCoordinates = (latitude: cluster.latitude, longitude: cluster.longitude)
        photoImportVM.nearbyPlaces = cluster.nearbyPlaces
        photoImportVM.searchRadiusUsed = cluster.searchRadiusUsed
        photoImportVM.photoThumbnail = thumbnailsForCluster(cluster).first

        showPlaceSelectionForCluster = true
    }

    /// Handles dismiss of the create post sheet.
    private func handlePostDismiss() {
        activeClusterId = nil
    }

    /// Handles post submission for a cluster: saves place, marks reviewed, returns to overview.
    private func handleClusterPostSubmission(clusterId: UUID, place: DetailPlace) {
        clusteringVM.markClusterReviewed(clusterId)
        showCreatePostForCluster = false

        Task {
            await photoImportVM.saveSelectedPlaceAfterReview()
        }
    }

    // MARK: - Helpers

    /// Returns UIImage thumbnails for a cluster's photo indices.
    private func thumbnailsForCluster(_ cluster: PhotoLocationCluster) -> [UIImage] {
        cluster.photoIndices.compactMap { idx in
            idx < photoImportVM.selectedImages.count ? photoImportVM.selectedImages[idx] : nil
        }
    }
}
