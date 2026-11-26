//  PhotoSample.swift
//  loc
//
//  Pure value describing the EXIF-derived location and capture time of one imported photo.

import Foundation
import ImageIO

struct PhotoSample: Equatable {
    var latitude: Double
    var longitude: Double
    /// Horizontal GPS error in meters (kCGImagePropertyGPSHPositioningError), if recorded.
    var accuracyMeters: Double?
    /// Capture instant; when the EXIF offset is unknown the wall-clock time is read as UTC.
    var capturedAt: Date?
    /// Offset of the capture location's local time from UTC in seconds, if known.
    var utcOffsetSeconds: Int?

    /// Builds a sample from raw image bytes, or nil when the photo has no GPS position.
    static func from(imageData data: Data) -> PhotoSample? {
        guard let coords = PhotoImportViewModel.extractGPSCoordinates(from: data) else { return nil }
        let props = imageProperties(data)
        let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let accuracy = (gps[kCGImagePropertyGPSHPositioningError as String] as? NSNumber)?.doubleValue
        let (date, offset) = parseCaptureTime(exif: exif, gps: gps)
        return PhotoSample(
            latitude: coords.latitude, longitude: coords.longitude,
            accuracyMeters: accuracy.flatMap { $0 >= 0 ? $0 : nil },
            capturedAt: date, utcOffsetSeconds: offset
        )
    }

    /// Reads the top-level image property dictionary from raw image bytes.
    private static func imageProperties(_ data: Data) -> [String: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return [:] }
        return props
    }

    /// Parses DateTimeOriginal with OffsetTimeOriginal, inferring the offset from the GPS UTC stamp when absent.
    static func parseCaptureTime(exif: [String: Any], gps: [String: Any]) -> (Date?, Int?) {
        guard let text = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String,
              let wallClockAsUTC = formatter("yyyy:MM:dd HH:mm:ss").date(from: text) else { return (nil, nil) }
        if let offsetText = exif["OffsetTimeOriginal"] as? String, let offset = parseOffset(offsetText) {
            return (wallClockAsUTC.addingTimeInterval(-Double(offset)), offset)
        }
        if let inferred = inferOffset(wallClock: wallClockAsUTC, gps: gps) {
            return (wallClockAsUTC.addingTimeInterval(-Double(inferred)), inferred)
        }
        return (wallClockAsUTC, nil)
    }

    /// Parses an EXIF offset such as "-05:00" into seconds.
    static func parseOffset(_ text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
        let sign = text.hasPrefix("-") ? -1 : 1
        return sign * (abs(hours) * 3600 + minutes * 60)
    }

    /// Infers the local UTC offset (15-minute steps) by comparing wall-clock time with the GPS UTC stamp.
    private static func inferOffset(wallClock: Date, gps: [String: Any]) -> Int? {
        guard let day = gps[kCGImagePropertyGPSDateStamp as String] as? String,
              let time = gps[kCGImagePropertyGPSTimeStamp as String] as? String,
              let utc = formatter("yyyy:MM:dd HH:mm:ss").date(from: "\(day) \(time.split(separator: ".")[0])") else { return nil }
        let raw = wallClock.timeIntervalSince(utc)
        let offset = Int((raw / 900).rounded()) * 900
        return abs(offset) <= 14 * 3600 ? offset : nil
    }

    /// Creates a UTC POSIX date formatter for the given format.
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }
}
