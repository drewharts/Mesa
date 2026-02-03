//
//  MapSnapshotService.swift
//  loc
//
//  Created by Claude on 1/31/25.
//

import MapKit
import UIKit

/// Service for generating static map snapshots with annotations.
class MapSnapshotService {

    /// Generates a map snapshot image with pin annotations for the given coordinates.
    func generateSnapshot(
        coordinates: [CLLocationCoordinate2D],
        size: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard !coordinates.isEmpty else {
            completion(nil)
            return
        }

        // Calculate region that fits all coordinates
        let region = calculateRegion(for: coordinates)

        // Configure snapshot options
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        options.showsBuildings = true
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)

        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                print("❌ [MapSnapshotService] Snapshot error: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }

            // Draw annotations on the snapshot
            let annotatedImage = self.drawAnnotations(
                on: snapshot,
                coordinates: coordinates
            )

            completion(annotatedImage)
        }
    }

    /// Async version of generateSnapshot.
    func generateSnapshot(
        coordinates: [CLLocationCoordinate2D],
        size: CGSize
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            generateSnapshot(coordinates: coordinates, size: size) { image in
                continuation.resume(returning: image)
            }
        }
    }

    /// Calculates a map region that fits all coordinates with padding.
    private func calculateRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Add padding (20% on each side)
        let latDelta = (maxLat - minLat) * 1.4
        let lonDelta = (maxLon - minLon) * 1.4

        // Ensure minimum span for single point or very close points
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.01),
            longitudeDelta: max(lonDelta, 0.01)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    /// Draws custom pin annotations on the map snapshot.
    private func drawAnnotations(
        on snapshot: MKMapSnapshotter.Snapshot,
        coordinates: [CLLocationCoordinate2D]
    ) -> UIImage {
        let image = snapshot.image

        UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
        image.draw(at: .zero)

        let pinSize: CGFloat = 32
        let pinColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // Dark gray/black

        for coordinate in coordinates {
            let point = snapshot.point(for: coordinate)

            // Draw pin circle
            let pinRect = CGRect(
                x: point.x - pinSize / 2,
                y: point.y - pinSize,
                width: pinSize,
                height: pinSize
            )

            // Draw shadow
            let shadowPath = UIBezierPath(ovalIn: pinRect.offsetBy(dx: 2, dy: 2))
            UIColor.black.withAlphaComponent(0.3).setFill()
            shadowPath.fill()

            // Draw pin background
            let pinPath = UIBezierPath(ovalIn: pinRect)
            pinColor.setFill()
            pinPath.fill()

            // Draw white border
            UIColor.white.setStroke()
            pinPath.lineWidth = 3
            pinPath.stroke()

            // Draw Mesa "A" icon in center (simplified as a dot for now)
            let dotSize: CGFloat = 12
            let dotRect = CGRect(
                x: point.x - dotSize / 2,
                y: point.y - pinSize + (pinSize - dotSize) / 2,
                width: dotSize,
                height: dotSize
            )
            let dotPath = UIBezierPath(ovalIn: dotRect)
            UIColor.white.setFill()
            dotPath.fill()
        }

        let annotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return annotatedImage ?? image
    }
}
