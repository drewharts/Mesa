//
//  NearbyPlaceCard.swift
//  loc
//
//  DUMB Component: Displays a single MKMapItem as a list row.
//  Used by NearbyDiscoverySheet in a vertical list.
//

import SwiftUI
import MapKit
import CoreLocation

struct NearbyPlaceCard: View {
    let mapItem: MKMapItem
    let searchCoordinate: CLLocationCoordinate2D?
    let onTap: () -> Void

    // MARK: - Computed Properties

    private var formattedDistance: String? {
        guard let searchCoordinate else { return nil }
        let itemCoord = mapItem.placemark.coordinate
        let distance = CLLocation(latitude: itemCoord.latitude, longitude: itemCoord.longitude)
            .distance(from: CLLocation(latitude: searchCoordinate.latitude, longitude: searchCoordinate.longitude))
        if distance < 1000 {
            return "\(Int(distance))m"
        }
        return String(format: "%.1fkm", distance / 1000)
    }

    private var categoryIcon: String {
        guard let category = mapItem.pointOfInterestCategory else { return "mappin" }
        switch category {
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .nightlife: return "wineglass.fill"
        case .bakery: return "birthday.cake.fill"
        case .store: return "bag.fill"
        case .hotel: return "bed.double.fill"
        case .gasStation: return "fuelpump.fill"
        case .parking: return "p.square.fill"
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .school, .university: return "graduationcap.fill"
        case .library: return "books.vertical.fill"
        case .museum: return "building.columns.fill"
        case .theater: return "theatermasks.fill"
        case .park, .nationalPark: return "leaf.fill"
        case .beach: return "beach.umbrella.fill"
        case .fitnessCenter: return "figure.run"
        case .stadium: return "sportscourt.fill"
        case .airport: return "airplane"
        case .publicTransport: return "bus.fill"
        default: return "mappin"
        }
    }

    private var categoryColor: Color {
        guard let category = mapItem.pointOfInterestCategory else { return .gray }
        switch category {
        case .restaurant, .bakery: return .orange
        case .cafe: return .brown
        case .nightlife: return .purple
        case .store: return .blue
        case .hotel: return .indigo
        case .park, .nationalPark, .beach: return .green
        case .hospital, .pharmacy: return .red
        case .fitnessCenter, .stadium: return .teal
        default: return .gray
        }
    }

    private var formattedAddress: String {
        let placemark = mapItem.placemark
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality
        ].compactMap { $0 }

        if components.isEmpty {
            return placemark.title ?? ""
        }
        return components.joined(separator: " ")
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                categoryIconView
                placeInfo
                Spacer()
                distanceLabel
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(uiColor: .systemBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Icon

    private var categoryIconView: some View {
        Image(systemName: categoryIcon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(categoryColor)
            .frame(width: 40, height: 40)
            .background(categoryColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Place Info

    private var placeInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(mapItem.name ?? "Unknown Place")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(formattedAddress)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Distance Label

    private var distanceLabel: some View {
        Group {
            if let distance = formattedDistance {
                Text(distance)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
}
