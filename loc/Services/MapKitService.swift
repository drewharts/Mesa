//
//  MapKitService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/2/25.
//

import Foundation
import MapKit

class MapKitService {
    // A shared instance (optional) for convenience.
    static let shared = MapKitService()

    enum TransportType: Int, CaseIterable {
        case automobile = 0, walking = 1, transit = 2

        var mkTransportType: MKDirectionsTransportType {
            switch self {
            case .automobile: return .automobile
            case .walking: return .walking
            case .transit: return .transit
            }
        }

        var iconName: String {
            switch self {
            case .automobile: return "car.fill"
            case .walking: return "figure.walk"
            case .transit: return "tram.fill"
            }
        }

        var displayName: String {
            switch self {
            case .automobile: return "Drive"
            case .walking: return "Walk"
            case .transit: return "Transit"
            }
        }
    }

    /// Check if transit routing is supported in the current region
    /// Note: This is a best-effort check - actual routing may still fail
    static func isTransitSupported() -> Bool {
        // MapKit doesn't have a direct way to check transit support
        // We'll assume it's supported in major cities and handle failures gracefully
        return true
    }

    /// Test transit routing specifically (for debugging)
    func testTransitRouting(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, completion: @escaping (Bool, String) -> Void) {
        print("🧪 [MapKitService] Testing transit routing availability...")

        // Try a simple transit request - MapKit will handle support detection
        calculateTravelTime(from: origin, to: destination, transportType: .transit) { timeInterval, error in
            if let error = error {
                completion(false, "Transit request failed: \(error.localizedDescription)")
            } else if let timeInterval = timeInterval {
                let minutes = timeInterval / 60.0
                completion(true, "Transit route found: \(String(format: "%.1f", minutes)) minutes")
            } else {
                completion(false, "No transit routes available between these locations")
            }
        }
    }

    /// Calculates travel time (in seconds) between an origin and destination for a specific transport type.
    func calculateTravelTime(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: TransportType = .automobile,
        completion: @escaping (TimeInterval?, Error?) -> Void
    ) {
        print("🗺️ [MapKitService] Calculating \(transportType.displayName) time from \(origin.latitude),\(origin.longitude) to \(destination.latitude),\(destination.longitude)")

        let sourcePlacemark = MKPlacemark(coordinate: origin)
        let destinationPlacemark = MKPlacemark(coordinate: destination)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = transportType.mkTransportType

        // For transit, ensure we have proper timing and settings
        if transportType == .transit {
            request.requestsAlternateRoutes = false // Transit usually has one main route
            request.departureDate = Date() // Set current time for transit departure
            // MKDirections transit routing should work in major cities like NYC

            // Add some debugging for transit
            print("🚇 [MapKitService] Transit request setup:")
            print("   - Departure date: \(request.departureDate?.description ?? "nil")")
            print("   - Transport type: \(request.transportType.rawValue)")
            print("   - Source: \(request.source?.placemark.coordinate.latitude ?? 0), \(request.source?.placemark.coordinate.longitude ?? 0)")
            print("   - Destination: \(request.destination?.placemark.coordinate.latitude ?? 0), \(request.destination?.placemark.coordinate.longitude ?? 0)")
        }

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                let nsError = error as NSError
                print("❌ [MapKitService] Error calculating \(transportType.displayName) time: \(error.localizedDescription)")
                print("   Error domain: \(nsError.domain), code: \(nsError.code)")

                // Handle specific MapKit errors
                if nsError.domain == "MKErrorDomain" {
                    switch nsError.code {
                    case 5: // MKErrorDirectionsNotFound - No directions available
                        if transportType == .transit {
                            // Calculate distance to provide better error context
                            let originLoc = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                            let destLoc = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
                            let distance = originLoc.distance(from: destLoc) * 0.000621371 // miles

                            if distance < 0.5 {
                                print("   MKErrorDirectionsNotFound: Transit not available for short distances (< 0.5 miles)")
                            } else {
                                print("   MKErrorDirectionsNotFound: No transit routes connect these locations")
                            }
                        } else {
                            print("   MKErrorDirectionsNotFound: No \(transportType.displayName.lowercased()) routes available for this route")
                        }
                    case 4: // MKErrorPlacemarkNotFound
                        print("   MKErrorPlacemarkNotFound: Location could not be geocoded")
                    case 3: // MKErrorLoadingThrottled
                        print("   MKErrorLoadingThrottled: Too many requests")
                    default:
                        print("   Unknown MKError code: \(nsError.code)")
                    }
                }

                completion(nil, error)
                return
            }

            if let route = response?.routes.first {
                let travelTime = route.expectedTravelTime
                print("✅ [MapKitService] \(transportType.displayName) time: \(travelTime) seconds (\(String(format: "%.1f", travelTime/60)) min)")

                // Additional debugging for transit routes
                if transportType == .transit {
                    print("🚇 [MapKitService] Transit route details:")
                    print("   - Distance: \(route.distance) meters")
                    print("   - Expected travel time: \(route.expectedTravelTime)")
                    print("   - Transport type: \(route.transportType.rawValue)")
                    print("   - Has steps: \(route.steps.count)")
                    if let firstStep = route.steps.first {
                        print("   - First step: \(firstStep.instructions)")
                    }
                }

                completion(travelTime, nil)
            } else {
                print("⚠️ [MapKitService] No route found for \(transportType.displayName)")
                print("   Available routes count: \(response?.routes.count ?? 0)")
                if let response = response {
                    print("   Response has \(response.routes.count) routes")
                    for (index, route) in response.routes.enumerated() {
                        print("   Route \(index): \(route.expectedTravelTime) seconds, distance: \(route.distance)m")
                    }
                }
                completion(nil, nil)
            }
        }
    }

    /// Calculates travel time for multiple transport types and returns them as a dictionary.
    func calculateTravelTimes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportTypes: [TransportType] = [.automobile, .walking, .transit],
        completion: @escaping ([TransportType: TimeInterval]?, Error?) -> Void
    ) {
        print("🚀 [MapKitService] Starting batch calculation for \(transportTypes.count) transport types")

        // Calculate distance to determine if transit makes sense
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distanceInMeters = originLocation.distance(from: destinationLocation)
        let distanceInMiles = distanceInMeters * 0.000621371 // Convert to miles

        print("📏 [MapKitService] Distance: \(String(format: "%.2f", distanceInMiles)) miles (\(Int(distanceInMeters)) meters)")

        var results: [TransportType: TimeInterval] = [:]
        var errors: [Error] = []
        var completedCount = 0
        let totalCount = transportTypes.count

        for transportType in transportTypes {
            // Skip transit for very short distances (less than 0.5 miles)
            // Transit doesn't make sense for walking distances
            if transportType == .transit && distanceInMiles < 0.5 {
                print("⚠️ [MapKitService] Skipping transit for short distance (\(String(format: "%.2f", distanceInMiles)) miles)")
                completedCount += 1
                if completedCount == totalCount {
                    completion(results, nil)
                }
                continue
            }

            calculateTravelTime(from: origin, to: destination, transportType: transportType) { timeInterval, error in
                completedCount += 1

                if let error = error {
                    errors.append(error)
                } else if let timeInterval = timeInterval {
                    results[transportType] = timeInterval
                }

                if completedCount == totalCount {
                    if !errors.isEmpty && results.isEmpty {
                        completion(nil, errors.first!)
                    } else {
                        completion(results, nil)
                    }
                }
            }
        }
    }
}
