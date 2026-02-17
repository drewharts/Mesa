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
        case automobile = 0, walking = 1, transit = 2, bicycle = 3

        var mkTransportType: MKDirectionsTransportType {
            switch self {
            case .automobile: return .automobile
            case .walking: return .walking
            case .transit: return .transit
            case .bicycle: return .cycling // MapKit has native cycling routing (macOS 11.0+/iOS 14.0+)
            }
        }

        var iconName: String {
            switch self {
            case .automobile: return "car.fill"
            case .walking: return "figure.walk"
            case .transit: return "tram.fill"
            case .bicycle: return "bicycle"
            }
        }

        var displayName: String {
            switch self {
            case .automobile: return "Drive"
            case .walking: return "Walk"
            case .transit: return "Transit"
            case .bicycle: return "Cycling"
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
        let sourcePlacemark = MKPlacemark(coordinate: origin)
        let destinationPlacemark = MKPlacemark(coordinate: destination)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = transportType.mkTransportType

        // For transit and cycling, use calculateETA which provides accurate ETAs
        if transportType == .transit || transportType == .bicycle {
            let directions = MKDirections(request: request)
            directions.calculateETA { response, error in
                if let error = error {
                    print("❌ [MapKitService] \(transportType.displayName) ETA failed: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }

                if let etaResponse = response {
                    let travelTime = etaResponse.expectedTravelTime
                    completion(travelTime, nil)
                    return
                }

                print("⚠️ [MapKitService] \(transportType.displayName) ETA returned nil response")
                completion(nil, nil)
            }
            return // Exit early for transit/cycling ETA
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
                completion(travelTime, nil)
            } else {
                completion(nil, nil)
            }
        }
    }

    /// Calculates travel time for multiple transport types and returns them as a dictionary.
    func calculateTravelTimes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportTypes: [TransportType] = [.automobile, .walking, .transit, .bicycle],
        completion: @escaping ([TransportType: TimeInterval]?, Error?) -> Void
    ) {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distanceInMiles = originLocation.distance(from: destinationLocation) * 0.000621371

        // Serial queue protects shared mutable state across concurrent MapKit callbacks
        let aggregationQueue = DispatchQueue(label: "com.loc.traveltime.aggregation")
        var results: [TransportType: TimeInterval] = [:]
        var errors: [Error] = []
        var completedCount = 0
        let totalCount = transportTypes.count

        for transportType in transportTypes {
            // Skip transit for very short distances — walking is always faster
            if transportType == .transit && distanceInMiles < 0.5 {
                aggregationQueue.async {
                    completedCount += 1
                    if completedCount == totalCount {
                        completion(results.isEmpty ? nil : results, nil)
                    }
                }
                continue
            }

            calculateTravelTime(from: origin, to: destination, transportType: transportType) { timeInterval, error in
                aggregationQueue.async {
                    completedCount += 1

                    if let error = error {
                        errors.append(error)
                    } else if let timeInterval = timeInterval {
                        results[transportType] = timeInterval
                    }

                    if completedCount == totalCount {
                        if !errors.isEmpty && results.isEmpty {
                            completion(nil, errors.first)
                        } else {
                            completion(results.isEmpty ? nil : results, nil)
                        }
                    }
                }
            }
        }
    }
}
