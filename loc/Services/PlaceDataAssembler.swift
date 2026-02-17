//
//  PlaceDataAssembler.swift
//  loc
//
//  Single canonical point for converting any raw data source into a DetailPlace.
//  Stateless utility — all methods are pure static functions with no dependencies.
//

import Foundation
import CoreLocation
import Supabase

enum PlaceDataAssembler {

    // MARK: - Assembly from PlaceRecord (Supabase rows)

    /// Converts a Supabase PlaceRecord into a DetailPlace.
    static func assemble(from record: PlaceRecord) -> DetailPlace {
        var place = DetailPlace(
            id: UUID(uuidString: record.id) ?? UUID(),
            name: record.name,
            address: record.address,
            city: record.city
        )

        applyRecordFields(from: record, to: &place)
        place.openHours = parseOpenHours(record.open_hours)
        place.coordinate = parsePostGISCoordinate(record.location)

        return place
    }

    /// Applies basic fields from a PlaceRecord onto a DetailPlace.
    private static func applyRecordFields(from record: PlaceRecord, to place: inout DetailPlace) {
        place.mapboxId = record.mapbox_id
        place.categories = record.categories
        place.phone = record.phone
        place.rating = record.rating
        place.userRatingsTotal = record.rating_count
        place.description = record.description
        place.priceLevel = record.price_level
        place.reservable = record.reservable
        place.servesBreakfast = record.serves_breakfast
        place.serversLunch = record.serves_lunch
        place.serversDinner = record.serves_dinner
        place.Instagram = record.instagram
        place.X = record.twitter
        place.photoUrls = record.photo_urls
        place.googlePlaceId = record.google_places_id
        place.source = record.source
        place.isCustom = record.is_custom
        place.menuUrl = record.menu_url
        place.websiteUrl = record.website
    }

    /// Parses AnyCodable open_hours into a string array, handling multiple formats.
    private static func parseOpenHours(_ openHoursData: AnyCodable?) -> [String]? {
        guard let openHoursData else { return nil }

        if let stringArray = openHoursData.value as? [String] {
            return stringArray
        } else if let dictArray = openHoursData.value as? [[String: String]] {
            return dictArray.compactMap { dict in
                guard let day = dict["day"], let hours = dict["hours"] else { return nil }
                return "\(day): \(hours)"
            }
        } else {
            print("⚠️ [PlaceDataAssembler] Could not convert open_hours to [String]: \(openHoursData.value)")
            return nil
        }
    }

    /// Parses a PostGIS LocationData geometry into a CLLocationCoordinate2D.
    private static func parsePostGISCoordinate(_ location: LocationData?) -> CLLocationCoordinate2D? {
        guard let location, let coords = location.coordinates, coords.count >= 2 else {
            if location != nil {
                print("⚠️ [PlaceDataAssembler] Could not parse location coordinates: \(location?.coordinates ?? [])")
            }
            return nil
        }
        return CLLocationCoordinate2D(latitude: coords[1], longitude: coords[0])
    }

    // MARK: - Assembly from BackendPlaceDTO (Mesa backend responses)

    /// Converts a backend DTO into a DetailPlace.
    static func assemble(from dto: BackendPlaceDTO) -> DetailPlace? {
        guard let placeId = UUID(uuidString: dto.id) else { return nil }

        var place = DetailPlace()
        place.id = placeId
        place.name = dto.name
        applyDTOFields(from: dto, to: &place)
        place.coordinate = parseDTOCoordinate(dto)

        return place
    }

    /// Applies fields from a BackendPlaceDTO onto a DetailPlace.
    private static func applyDTOFields(from dto: BackendPlaceDTO, to place: inout DetailPlace) {
        place.address = dto.address
        place.city = dto.city
        place.description = dto.description
        place.mapboxId = dto.mapboxId
        place.categories = dto.categories
        place.openHours = dto.openHours
        place.phone = dto.phone
        place.priceLevel = dto.priceLevel
        place.rating = dto.rating
        place.userRatingsTotal = dto.ratingCount
        place.reservable = dto.reservable
        place.servesBreakfast = dto.servesBreakfast
        place.serversLunch = dto.servesLunch
        place.serversDinner = dto.servesDinner
        place.Instagram = dto.instagram
        place.X = dto.twitter
        place.menuUrl = dto.menuUrl
        place.websiteUrl = dto.website
        place.isCustom = dto.isCustom
        place.googlePlaceId = dto.googlePlacesId
        place.aiSuggestionReason = dto.aiSuggestionReason

        if let thumbnailUrl = dto.thumbnailUrl, !thumbnailUrl.isEmpty {
            place.photoUrls = [thumbnailUrl]
        }
    }

    /// Parses coordinate from a BackendPlaceDTO, trying coordinate then location fields.
    private static func parseDTOCoordinate(_ dto: BackendPlaceDTO) -> CLLocationCoordinate2D? {
        let coords = dto.coordinate ?? dto.location
        guard let lat = coords?.latitude, let lng = coords?.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    // MARK: - Placeholder Assembly (search suggestions)

    /// Creates a search placeholder DetailPlace with sentinel UUID.
    static func assemblePlaceholder(
        googlePlaceId: String,
        name: String,
        address: String?,
        coordinate: CLLocationCoordinate2D,
        source: String
    ) -> DetailPlace {
        DetailPlace(
            googlePlaceId: googlePlaceId,
            name: name,
            address: address,
            coordinate: coordinate,
            source: source
        )
    }

    // MARK: - Merge

    /// Merges overlay onto base. Overlay fields win unless nil.
    /// Special rules: coordinate prefers valid over invalid, isCustom preserved from base,
    /// openHours uses overlay unless empty, id always uses overlay (authoritative Supabase UUID).
    static func merge(base: DetailPlace, overlay: DetailPlace) -> DetailPlace {
        var merged = overlay
        // Keep overlay.id — it's the authoritative Supabase UUID from the backend.
        merged.isCustom = base.isCustom

        // Use base coordinate only if valid; otherwise use overlay coordinate
        if let baseCoord = base.coordinate, baseCoord.isValidForNavigation {
            merged.coordinate = base.coordinate
        }

        if merged.openHours == nil || merged.openHours?.isEmpty == true {
            merged.openHours = base.openHours
        }

        return merged
    }

    // MARK: - Enrichment Check

    /// Returns true if place has incomplete data warranting backend enrichment.
    /// Custom places never need enrichment.
    static func needsEnrichment(_ place: DetailPlace) -> Bool {
        if place.isCustom == true { return false }
        let missingRating = place.rating == nil
        let missingReviewCount = place.userRatingsTotal == nil
        let missingCategories = place.categories == nil || place.categories?.isEmpty == true
        return missingRating || missingReviewCount || missingCategories
    }
}
