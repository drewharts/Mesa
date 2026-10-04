//
//  GoogleMapView.swift
//  loc
//
//  UIKit GMSMapView wrapper (Google Maps SDK) for the main map screen, replacing the
//  MapKit-based NativeMapView. Annotation clustering is delegated entirely to
//  GMUClusterManager (Google Maps SDK for iOS Utils) — a mature, production-tested
//  clustering engine — rather than a hand-rolled implementation. Unlike MapKit's built-in
//  clustering (whose distance threshold is fixed and doesn't scale with custom marker image
//  size), GMUNonHierarchicalDistanceBasedAlgorithm takes an explicit clusterDistancePoints
//  value we can tune to match our actual marker footprint, and GMUDefaultClusterRenderer
//  provides built-in split/merge animations for free.
//
//  Camera contract: mapPosition mirrors exactly what MapContainerView/MainView already
//  write to it today (.camera(MapCamera(centerCoordinate:distance:)) or
//  .region(MKCoordinateRegion(...))) — those call sites are unchanged by this file. We
//  translate to/from GMSCameraPosition internally so the rest of the app never needs to
//  know which map SDK is actually rendering.
//

import SwiftUI
import MapKit
import GoogleMaps
import GoogleMapsUtils

struct GoogleMapView: UIViewRepresentable {
    @Binding var mapPosition: MapCameraPosition
    let annotations: [MapAnnotationItem]
    let isSatelliteMap: Bool
    /// Per-item selection test, since a "selected" place's identity is looked up differently
    /// depending on which layer it belongs to (network/community share a place id scheme,
    /// trip pins have their own placeId, city pins are never treated as "selected").
    var isAnnotationSelected: (MapAnnotationItem) -> Bool

    var onCameraSettled: ((MKCoordinateRegion) -> Void)?
    var onNetworkTap: ((PlaceAnnotation) -> Void)?
    var onCommunityTap: ((CommunityPlaceMarker) -> Void)?
    var onCityTap: ((CityAnnotation) -> Void)?
    var onTripTap: ((String) -> Void)?
    var onLongPressCreatePlace: ((CLLocationCoordinate2D) -> Void)?
    var onDiscoveryTap: ((CLLocationCoordinate2D) -> Void)?
    var annotationImageProvider: (MapAnnotationItem, Bool) -> UIImage?

    /// On-screen point distance below which GMUClusterManager merges pins into a cluster
    /// badge. Deliberately smaller than the markers' own visual footprint (community/emoji
    /// circles up to ~70pt, profile-photo composites up to 60pt wide) — pins are allowed to
    /// overlap somewhat before clustering kicks in, so merging only happens once you're
    /// zoomed out noticeably farther, rather than as soon as two pins first touch. Raise this
    /// to cluster sooner (at less zoom-out); lower it to require even more zoom-out first.
    /// MapKit's built-in clustering had no equivalent tunable — this is the parameter that
    /// was missing there.
    static let clusterDistancePoints: UInt = 20

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: .zero)
        mapView.isMyLocationEnabled = false // user location rendered as our own baked-image marker
        mapView.settings.compassButton = false
        mapView.mapType = isSatelliteMap ? .hybrid : .normal
        context.coordinator.setUpClusterManager(on: mapView)
        context.coordinator.applyCameraPosition(mapPosition, on: mapView, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.parent = self
        mapView.mapType = isSatelliteMap ? .hybrid : .normal
        context.coordinator.syncAnnotations(annotations, on: mapView)
        context.coordinator.syncCameraIfNeeded(mapPosition, on: mapView)
        context.coordinator.syncSelection()
    }

    // MARK: - Coordinator

    // @MainActor is required here (not just inferred): GMSMapViewDelegate/GMUClusterRendererDelegate
    // are unannotated Objective-C protocols, so Swift's concurrency checker doesn't know their
    // callbacks run on the main thread the way it does for Apple-authored protocols like
    // MKMapViewDelegate — without this, calls into @MainActor-isolated code (e.g.
    // MapMarkerImageFactory) from these delegate methods fail to compile.
    @MainActor
    final class Coordinator: NSObject, GMSMapViewDelegate, GMUClusterRendererDelegate {
        var parent: GoogleMapView
        private weak var mapView: GMSMapView?
        private var clusterManager: GMUClusterManager!

        /// Clusterable items (network/community/city), owned entirely by clusterManager.
        private var clusterableItemsById: [String: MapAnnotationItem] = [:]
        /// Non-clusterable items (trip pins, user location dot) added directly as plain markers —
        /// trip pins never cluster (would break the numbered day-by-day sequence) and the user
        /// location dot should always stay individually visible.
        private var directMarkersById: [String: GMSMarker] = [:]

        private var lastAppliedCameraSignature: String?
        private var isApplyingProgrammaticCameraChange = false
        /// Becomes true once applyCameraPosition has successfully applied a real camera derived
        /// from `mapPosition`. Until then, GMSMapView is still sitting at its own arbitrary
        /// uninitialized default camera — idleAt must not write that back into the mapPosition
        /// binding, or it silently clobbers the app's own "center on user location" logic with
        /// a meaningless default location before the user's real location is even known yet.
        private var hasAppliedInitialCamera = false
        private var highlightedStableIds: Set<String> = []

        init(_ parent: GoogleMapView) {
            self.parent = parent
        }

        func setUpClusterManager(on mapView: GMSMapView) {
            self.mapView = mapView
            let iconGenerator = GMUDefaultClusterIconGenerator()
            // Swift imports this initializer as failable even though it can't actually fail for
            // any UInt input — force-unwrap is safe here.
            let algorithm = GMUNonHierarchicalDistanceBasedAlgorithm(
                clusterDistancePoints: GoogleMapView.clusterDistancePoints
            )!
            let renderer = GMUDefaultClusterRenderer(mapView: mapView, clusterIconGenerator: iconGenerator)
            // Clusters of 2+ overlapping pins should show a badge — the library's own default
            // (4) would leave 2-3 visually-overlapping pins rendered individually.
            renderer.minimumClusterSize = 2
            renderer.delegate = self
            clusterManager = GMUClusterManager(map: mapView, algorithm: algorithm, renderer: renderer)
            clusterManager.setMapDelegate(self)
        }

        // MARK: Annotation diffing

        /// Diffs the incoming annotation array against what's currently displayed, by stableId.
        /// Clusterable items (network/community/city) are rebuilt wholesale into clusterManager
        /// on any change — GMUClusterManager doesn't expose incremental per-item diffing the way
        /// MapKit's addAnnotations/removeAnnotations did, and re-running its algorithm over the
        /// current item set is cheap (this is the same pattern Google's own sample code uses).
        /// Non-clusterable items (trip/userLocation) are still diffed precisely as plain markers.
        func syncAnnotations(_ newItems: [MapAnnotationItem], on mapView: GMSMapView) {
            let newClusterable = newItems.filter(Self.isClusterable)
            let newDirect = newItems.filter { !Self.isClusterable($0) }

            syncClusterableItems(newClusterable)
            syncDirectMarkers(newDirect, on: mapView)
        }

        /// Whether this layer participates in GMUClusterManager's clustering.
        private static func isClusterable(_ item: MapAnnotationItem) -> Bool {
            switch item.layer {
            case .network, .community, .city: return true
            case .trip, .userLocation: return false
            }
        }

        private func syncClusterableItems(_ newItems: [MapAnnotationItem]) {
            let newById = Dictionary(uniqueKeysWithValues: newItems.map { ($0.stableId, $0) })
            guard Set(newById.keys) != Set(clusterableItemsById.keys) else {
                clusterableItemsById = newById
                return
            }
            clusterManager.clearItems()
            for item in newItems {
                clusterManager.add(item)
            }
            clusterableItemsById = newById
            clusterManager.cluster()
        }

        private func syncDirectMarkers(_ newItems: [MapAnnotationItem], on mapView: GMSMapView) {
            let newById = Dictionary(uniqueKeysWithValues: newItems.map { ($0.stableId, $0) })
            let currentIds = Set(directMarkersById.keys)
            let newIds = Set(newById.keys)

            for id in currentIds.subtracting(newIds) {
                directMarkersById[id]?.map = nil
                directMarkersById.removeValue(forKey: id)
            }
            for id in newIds.subtracting(currentIds) {
                guard let item = newById[id] else { continue }
                let marker = GMSMarker(position: item.coordinate)
                marker.userData = item
                marker.map = mapView
                directMarkersById[id] = marker
                configureDirectMarker(marker, for: item)
            }
            for id in currentIds.intersection(newIds) {
                guard let marker = directMarkersById[id], let item = newById[id] else { continue }
                marker.position = item.coordinate
                configureDirectMarker(marker, for: item)
            }
        }

        private func configureDirectMarker(_ marker: GMSMarker, for item: MapAnnotationItem) {
            let isSelected = parent.isAnnotationSelected(item)
            marker.icon = parent.annotationImageProvider(item, isSelected)
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            marker.zIndex = isSelected ? 2 : 0
        }

        // MARK: Camera

        /// Applies a camera position unconditionally (used on initial creation).
        func applyCameraPosition(_ position: MapCameraPosition, on mapView: GMSMapView, animated: Bool) {
            guard let region = region(from: position) else {
                #if DEBUG
                print("[MapCenter] applyCameraPosition: region(from:) returned nil for \(position) — skipping")
                #endif
                return
            }
            isApplyingProgrammaticCameraChange = true
            hasAppliedInitialCamera = true
            // Only lock in the dedup signature once we've computed a camera against a
            // laid-out (non-zero-bounds) map view. A pre-layout GMSMapView returns a wildly
            // over-zoomed-out camera from camera(for:insets:) instead of nil (see googleCamera),
            // so locking in here would make syncCameraIfNeeded skip every future attempt and
            // leave the map stuck zoomed all the way out forever. Leaving the signature unset
            // lets the very next updateUIView (fires almost immediately, once SwiftUI finishes
            // laying out the view) retry and land on a correctly-fitted zoom.
            let hasValidBounds = mapView.bounds.width > 0 && mapView.bounds.height > 0
            if hasValidBounds {
                lastAppliedCameraSignature = signature(for: region)
            }
            let camera = googleCamera(for: region, on: mapView)
            #if DEBUG
            print("[MapCenter] applyCameraPosition: target=\(camera.target) zoom=\(camera.zoom) animated=\(animated) mapViewBounds=\(mapView.bounds) locked=\(hasValidBounds)")
            #endif
            if animated {
                mapView.animate(to: camera)
            } else {
                mapView.camera = camera
            }
        }

        /// Applies the SwiftUI-driven camera position only if it represents a genuinely new
        /// request, distinguishing external changes (recenter button, search navigation) from
        /// our own write-back of the user's last pan (which already matches the map's state).
        func syncCameraIfNeeded(_ position: MapCameraPosition, on mapView: GMSMapView) {
            guard let region = region(from: position) else { return }
            let newSignature = signature(for: region)
            guard newSignature != lastAppliedCameraSignature else {
                #if DEBUG
                print("[MapCenter] syncCameraIfNeeded: signature unchanged (\(newSignature)) — skipping re-apply")
                #endif
                return
            }
            applyCameraPosition(position, on: mapView, animated: true)
        }

        /// Converts an MKCoordinateRegion into a GMSCameraPosition that frames the same bounds,
        /// using the map's own camera(for:insets:) so we don't have to hand-roll a span→zoom
        /// formula the way a raw zoom-level camera would require.
        private func googleCamera(for region: MKCoordinateRegion, on mapView: GMSMapView) -> GMSCameraPosition {
            let halfLat = region.span.latitudeDelta / 2
            let halfLon = region.span.longitudeDelta / 2
            let bounds = GMSCoordinateBounds(
                coordinate: CLLocationCoordinate2D(
                    latitude: region.center.latitude - halfLat,
                    longitude: region.center.longitude - halfLon
                ),
                coordinate: CLLocationCoordinate2D(
                    latitude: region.center.latitude + halfLat,
                    longitude: region.center.longitude + halfLon
                )
            )
            // camera(for:insets:) doesn't return nil for a zero-size (not-yet-laid-out) map
            // view the way its documentation implies — it returns a valid-looking but wildly
            // over-zoomed-out camera (observed: zoom ~2, i.e. most of the globe) instead. Guard
            // on real bounds ourselves rather than trusting its return value in that case.
            guard mapView.bounds.width > 0, mapView.bounds.height > 0 else {
                #if DEBUG
                print("[MapCenter] googleCamera: mapView not yet laid out (bounds=\(mapView.bounds)) — using fallback zoom 15, will retry once laid out")
                #endif
                return GMSCameraPosition(target: region.center, zoom: 15, bearing: 0, viewingAngle: 0)
            }
            if let fitted = mapView.camera(for: bounds, insets: .zero) {
                return fitted
            }
            #if DEBUG
            print("[MapCenter] googleCamera: camera(for:insets:) returned nil (mapViewBounds=\(mapView.bounds)) — using fallback zoom 15")
            #endif
            return GMSCameraPosition(target: region.center, zoom: 15, bearing: 0, viewingAngle: 0)
        }

        /// Extracts a plain MKCoordinateRegion from either supported MapCameraPosition case
        /// used across the app today (.region or .camera). Returns nil for .automatic/other
        /// cases, which are left as "don't move the camera" rather than guessed at.
        private func region(from position: MapCameraPosition) -> MKCoordinateRegion? {
            if let region = position.region {
                return region
            }
            if let camera = position.camera {
                // Approximate MapCamera's (centerCoordinate, distance-in-meters) as a coordinate
                // span, matching how googleCamera(for:) expects to receive camera intent.
                let metersPerDegreeLatitude = 111_320.0
                let latDelta = min(max(camera.distance / metersPerDegreeLatitude, 0.001), 60)
                let lonDelta = min(max(latDelta / max(cos(camera.centerCoordinate.latitude * .pi / 180), 0.1), 0.001), 60)
                return MKCoordinateRegion(
                    center: camera.centerCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
                )
            }
            return nil
        }

        /// A coarse, epsilon-tolerant string signature used to detect "is this actually a new
        /// camera request" without requiring MapCameraPosition to be Equatable.
        private func signature(for region: MKCoordinateRegion) -> String {
            func round4(_ value: Double) -> Double { (value * 10_000).rounded() / 10_000 }
            return "\(round4(region.center.latitude)),\(round4(region.center.longitude)),\(round4(region.span.latitudeDelta)),\(round4(region.span.longitudeDelta))"
        }

        /// Derives an MKCoordinateRegion from the map's actual visible bounds — used to write
        /// the user's pan/zoom back into the mapPosition binding and to report camera settles.
        private func currentRegion(on mapView: GMSMapView) -> MKCoordinateRegion {
            let bounds = GMSCoordinateBounds(region: mapView.projection.visibleRegion())
            let center = CLLocationCoordinate2D(
                latitude: (bounds.northEast.latitude + bounds.southWest.latitude) / 2,
                longitude: (bounds.northEast.longitude + bounds.southWest.longitude) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: abs(bounds.northEast.latitude - bounds.southWest.latitude),
                longitudeDelta: abs(bounds.northEast.longitude - bounds.southWest.longitude)
            )
            return MKCoordinateRegion(center: center, span: span)
        }

        // MARK: GMSMapViewDelegate — camera

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            if gesture {
                isApplyingProgrammaticCameraChange = false
            }
        }

        /// GMSMapView has a native "camera came to rest" callback, unlike MKMapView (which has
        /// no mapView(_:idleAt:)-style delegate method and needed a manual debounce timer here).
        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            let region = currentRegion(on: mapView)
            #if DEBUG
            print("[MapCenter] idleAt: target=\(position.target) hasAppliedInitialCamera=\(hasAppliedInitialCamera) isApplyingProgrammaticCameraChange=\(isApplyingProgrammaticCameraChange)")
            #endif
            // Ignore GMSMapView's own arbitrary startup camera settling before we've ever
            // applied a real one — see hasAppliedInitialCamera's doc comment.
            if !isApplyingProgrammaticCameraChange && hasAppliedInitialCamera {
                lastAppliedCameraSignature = signature(for: region)
                parent.mapPosition = .region(region)
            }
            // Reset here (not just on a user gesture in willMove) so a subsequent programmatic
            // camera change's own settle-write-back isn't permanently suppressed — previously
            // this only ever cleared on a real pan/pinch, leaving it stuck true after the very
            // first programmatic move for the rest of the map's lifetime.
            isApplyingProgrammaticCameraChange = false
            clusterManager.cluster()
            if hasAppliedInitialCamera {
                parent.onCameraSettled?(region)
            }
        }

        // MARK: Selection visuals

        /// Re-renders clusterManager's markers so willRenderMarker picks up the current
        /// selection state, and refreshes any directly-added (non-clusterable) markers in place.
        func syncSelection() {
            var newHighlighted: Set<String> = []
            for (stableId, item) in clusterableItemsById where parent.isAnnotationSelected(item) {
                newHighlighted.insert(stableId)
            }
            for (stableId, marker) in directMarkersById {
                guard let item = marker.userData as? MapAnnotationItem else { continue }
                if parent.isAnnotationSelected(item) { newHighlighted.insert(stableId) }
            }
            guard newHighlighted != highlightedStableIds else { return }
            highlightedStableIds = newHighlighted

            clusterManager.cluster()
            for (_, marker) in directMarkersById {
                guard let item = marker.userData as? MapAnnotationItem else { continue }
                configureDirectMarker(marker, for: item)
            }
        }

        // MARK: GMUClusterRendererDelegate — custom marker icons

        /// Supplies our existing SwiftUI-rendered marker images (see MapMarkerImageFactory) for
        /// every marker the renderer is about to display, whether it's a merged cluster badge or
        /// an individual pin. This is the one hook where .icon/.groundAnchor/.zIndex are honored.
        func renderer(_ renderer: GMUClusterRenderer, willRenderMarker marker: GMSMarker) {
            if let cluster = marker.userData as? GMUCluster {
                marker.icon = MapMarkerImageFactory.shared.clusterImage(count: Int(cluster.count))
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.zIndex = 1
                return
            }
            guard let item = marker.userData as? MapAnnotationItem else { return }
            let isSelected = highlightedStableIds.contains(item.stableId)
            let image = parent.annotationImageProvider(item, isSelected)
            marker.icon = image

            if case .network = item.layer {
                // Emulates the old MapKit centerOffset trick — anchor the marker at the bottom-
                // center of its visual content rather than the center. groundAnchor is normalized
                // (0-1) against the full image, but MapMarkerImageFactory pads every image with a
                // transparent margin (renderPadding) for its shadow to fade into, so the visual
                // content's true bottom edge sits slightly short of y=1.0 — not exactly at it.
                let bottomInset = image.map { MapMarkerImageFactory.renderPadding / $0.size.height } ?? 0
                marker.groundAnchor = CGPoint(x: 0.5, y: 1.0 - bottomInset)
            } else {
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            }
            marker.zIndex = isSelected ? 2 : 0
        }

        // MARK: GMSMapViewDelegate — tap routing

        /// Routes taps to the app's existing handler methods, recentering the camera on the
        /// tapped pin. GMUClusterManager forwards every marker tap here (after first handling any
        /// of its own cluster-specific logic) — userData tells us whether it's a merged cluster
        /// or an individual item.
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let cluster = marker.userData as? GMUCluster {
                zoomToFit(cluster, on: mapView)
                return true
            }
            guard let item = marker.userData as? MapAnnotationItem else { return false }

            centerCamera(on: item.coordinate, on: mapView)

            switch item.layer {
            case .network(let annotation): parent.onNetworkTap?(annotation)
            case .community(let communityMarker): parent.onCommunityTap?(communityMarker)
            case .city(let city): parent.onCityTap?(city)
            case .trip(let trip): parent.onTripTap?(trip.placeId)
            case .userLocation: break
            }
            return true
        }

        /// Recenters the map on a tapped annotation's coordinate, preserving the current zoom
        /// level. Writes through the mapPosition binding rather than calling mapView.camera
        /// directly, so the existing reentrancy-guarded camera pipeline (syncCameraIfNeeded)
        /// applies the animation exactly once, consistently with every other camera change.
        private func centerCamera(on coordinate: CLLocationCoordinate2D, on mapView: GMSMapView) {
            let currentSpan = currentRegion(on: mapView).span
            parent.mapPosition = .region(MKCoordinateRegion(center: coordinate, span: currentSpan))
        }

        private func zoomToFit(_ cluster: GMUCluster, on mapView: GMSMapView) {
            guard !cluster.items.isEmpty else { return }
            var bounds = GMSCoordinateBounds()
            for item in cluster.items {
                bounds = bounds.includingCoordinate(item.position)
            }
            let update = GMSCameraUpdate.fit(bounds, withPadding: 60)
            mapView.animate(with: update)
        }

        // MARK: Gestures — long-press-to-create-place and tap-to-discover

        /// GMSMapViewDelegate has native tap/long-press callbacks for empty map taps, unlike
        /// MapKit (which needed manual UIGestureRecognizers attached here to distinguish a
        /// background tap from an annotation tap).
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            parent.onDiscoveryTap?(coordinate)
        }

        func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
            parent.onLongPressCreatePlace?(coordinate)
        }
    }
}
