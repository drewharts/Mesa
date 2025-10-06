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

        // Additional configuration for transit
        if transportType == .transit {
            // Set departure date to current time for transit
            request.departureDate = Date()
            print("🚇 [MapKitService] Transit request configured with departure date: \(Date())")
        }

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("❌ [MapKitService] Error calculating \(transportType.displayName) time: \(error.localizedDescription)")
                print("❌ [MapKitService] Error domain: \((error as NSError).domain), code: \((error as NSError).code)")

                // For transit, try alternative approach
                if transportType == .transit {
                    self.calculateTransitTimeAlternative(from: origin, to: destination, completion: completion)
                    return
                }

                completion(nil, error)
                return
            }

            if let route = response?.routes.first {
                let travelTime = route.expectedTravelTime
                print("✅ [MapKitService] \(transportType.displayName) time: \(travelTime) seconds (\(String(format: "%.1f", travelTime/60)) min)")
                completion(travelTime, nil)
            } else {
                print("⚠️ [MapKitService] No route found for \(transportType.displayName)")

                // For transit, try alternative approach if no routes found
                if transportType == .transit {
                    self.calculateTransitTimeAlternative(from: origin, to: destination, completion: completion)
                    return
                }

                completion(nil, nil)
            }
        }
    }

    /// Alternative transit calculation method with improved timing
    private func calculateTransitTimeAlternative(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        completion: @escaping (TimeInterval?, Error?) -> Void
    ) {
        print("🚇 [MapKitService] Trying alternative transit calculation...")
        fallbackTransitCalculation(from: origin, to: destination, completion: completion)
    }

    /// Fallback transit calculation using regular MKDirections with transit type
    private func fallbackTransitCalculation(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        completion: @escaping (TimeInterval?, Error?) -> Void
    ) {
        print("🚇 [MapKitService] Using fallback transit calculation")

        let sourcePlacemark = MKPlacemark(coordinate: origin)
        let destinationPlacemark = MKPlacemark(coordinate: destination)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .transit
        request.departureDate = Date()
        request.arrivalDate = nil // Allow flexible arrival time

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("❌ [MapKitService] Fallback transit error: \(error.localizedDescription)")
                // Try with different time settings
                self.finalFallbackTransit(from: origin, to: destination, completion: completion)
                return
            }

            if let route = response?.routes.first {
                let travelTime = route.expectedTravelTime
                print("✅ [MapKitService] Fallback transit success: \(travelTime) seconds (\(String(format: "%.1f", travelTime/60)) min)")
                completion(travelTime, nil)
            } else {
                print("⚠️ [MapKitService] Fallback transit found no routes")
                self.finalFallbackTransit(from: origin, to: destination, completion: completion)
            }
        }
    }

    /// Final fallback - try with different departure time
    private func finalFallbackTransit(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        completion: @escaping (TimeInterval?, Error?) -> Void
    ) {
        print("🚇 [MapKitService] Final fallback transit attempt")

        let sourcePlacemark = MKPlacemark(coordinate: origin)
        let destinationPlacemark = MKPlacemark(coordinate: destination)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .transit
        request.departureDate = Date().addingTimeInterval(3600) // Try 1 hour from now

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                print("❌ [MapKitService] Final transit fallback failed: \(error.localizedDescription)")
                completion(nil, nil) // Give up
                return
            }

            if let route = response?.routes.first {
                let travelTime = route.expectedTravelTime
                print("✅ [MapKitService] Final transit fallback success: \(travelTime) seconds (\(String(format: "%.1f", travelTime/60)) min)")
                completion(travelTime, nil)
            } else {
                print("⚠️ [MapKitService] All transit calculations failed")
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
        var results: [TransportType: TimeInterval] = [:]
        var errors: [Error] = []
        var completedCount = 0
        let totalCount = transportTypes.count

        for transportType in transportTypes {
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
