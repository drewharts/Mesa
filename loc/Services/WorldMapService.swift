//
//  WorldMapService.swift
//  loc
//
//  Parses bundled GeoJSON and projects country boundaries into normalized Mercator paths.
//

import Foundation
import CoreGraphics

/// Represents a single country's pre-projected map paths.
struct CountryShape: Identifiable {
    let id: String       // ISO_A2 code
    let paths: [CGPath]  // Pre-projected, normalized Mercator paths
}

@MainActor
final class WorldMapService {
    static let shared = WorldMapService()

    /// Cached country shapes, loaded lazily on first access.
    private(set) var countryShapes: [CountryShape] = []

    /// Natural width-to-height ratio of the projected map data.
    private(set) var aspectRatio: CGFloat = 2.0
    private var hasLoaded = false

    private init() {}

    /// Loads and projects the GeoJSON data. Safe to call multiple times; only loads once.
    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        countryShapes = loadAndProject()
    }

    // MARK: - GeoJSON Loading & Projection

    /// Loads the bundled GeoJSON, projects coordinates via Mercator, and normalizes to 0...1 range.
    private func loadAndProject() -> [CountryShape] {
        guard let url = Bundle.main.url(forResource: "countries-110m", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data) else {
            print("WorldMapService Failed to load countries GeoJSON")
            return []
        }

        // First pass: collect all projected points to determine bounds
        var allProjected: [(x: Double, y: Double)] = []
        var featureRings: [(isoA2: String, rings: [[(x: Double, y: Double)]])] = []

        for feature in collection.features {
            guard let isoA2 = feature.properties.isoA2, isoA2 != "-99" else { continue }
            let polygonRings = extractRings(from: feature.geometry)
            var projectedRings: [[(x: Double, y: Double)]] = []

            for ring in polygonRings {
                let projected = ring.map { coord -> (x: Double, y: Double) in
                    let p = mercatorProject(lon: coord[0], lat: coord[1])
                    allProjected.append(p)
                    return p
                }
                projectedRings.append(projected)
            }
            featureRings.append((isoA2: isoA2, rings: projectedRings))
        }

        guard !allProjected.isEmpty else { return [] }

        // Compute bounds for normalization
        let bounds = computeBounds(allProjected)
        let rangeX = bounds.maxX - bounds.minX
        let rangeY = bounds.maxY - bounds.minY
        if rangeY > 0 {
            aspectRatio = CGFloat(rangeX / rangeY)
        }

        // Second pass: normalize and build CGPaths
        return buildCountryShapes(from: featureRings, bounds: bounds)
    }

    /// Extracts coordinate rings from a GeoJSON geometry (handles Polygon and MultiPolygon).
    private func extractRings(from geometry: GeoJSONGeometry) -> [[[Double]]] {
        switch geometry.coordinates {
        case .polygon(let rings):
            return rings
        case .multiPolygon(let polygons):
            return polygons.flatMap { $0 }
        }
    }

    /// Projects a geographic coordinate to Mercator (x = lon, y = ln(tan(pi/4 + lat/2))).
    private func mercatorProject(lon: Double, lat: Double) -> (x: Double, y: Double) {
        let clampedLat = min(max(lat, -85.0), 85.0)
        let latRad = clampedLat * .pi / 180.0
        let x = lon
        let y = log(tan(.pi / 4.0 + latRad / 2.0)) * (180.0 / .pi)
        return (x, y)
    }

    /// Computes the bounding box of all projected points.
    private func computeBounds(_ points: [(x: Double, y: Double)]) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        var minX = Double.infinity, minY = Double.infinity
        var maxX = -Double.infinity, maxY = -Double.infinity
        for p in points {
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }
        return (minX, minY, maxX, maxY)
    }

    /// Normalizes projected rings and builds CountryShape objects with CGPaths.
    private func buildCountryShapes(
        from featureRings: [(isoA2: String, rings: [[(x: Double, y: Double)]])],
        bounds: (minX: Double, minY: Double, maxX: Double, maxY: Double)
    ) -> [CountryShape] {
        let rangeX = bounds.maxX - bounds.minX
        let rangeY = bounds.maxY - bounds.minY
        guard rangeX > 0, rangeY > 0 else { return [] }

        // Group rings by ISO code (multiple features can share the same code)
        var grouped: [String: [[(x: Double, y: Double)]]] = [:]
        for entry in featureRings {
            grouped[entry.isoA2, default: []].append(contentsOf: entry.rings)
        }

        return grouped.compactMap { isoA2, rings in
            let paths = rings.compactMap { ring -> CGPath? in
                guard ring.count >= 3 else { return nil }
                let path = CGMutablePath()
                for (i, point) in ring.enumerated() {
                    let nx = (point.x - bounds.minX) / rangeX
                    // Flip Y so north is up
                    let ny = 1.0 - (point.y - bounds.minY) / rangeY
                    let cgPoint = CGPoint(x: nx, y: ny)
                    if i == 0 {
                        path.move(to: cgPoint)
                    } else {
                        path.addLine(to: cgPoint)
                    }
                }
                path.closeSubpath()
                return path
            }
            guard !paths.isEmpty else { return nil }
            return CountryShape(id: isoA2, paths: paths)
        }
    }
}
