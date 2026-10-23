//
//  TripPlaceRowView.swift
//  loc
//
//  Single place row in the trip overview itinerary
//

import SwiftUI

/// Extracts a display time (e.g. "9:40 AM", "12:15") from a free-form trip note.
enum TripNoteTime {
    private static let regex = try? NSRegularExpression(
        pattern: "\\b(1[0-2]|0?[1-9]):[0-5][0-9](\\s?[AaPp]\\.?[Mm]\\.?)?",
        options: []
    )

    static func time(in note: String?) -> String? {
        guard let note, !note.isEmpty, let regex else { return nil }
        let range = NSRange(note.startIndex..<note.endIndex, in: note)
        guard let match = regex.firstMatch(in: note, options: [], range: range),
              let swiftRange = Range(match.range, in: note) else { return nil }
        return String(note[swiftRange])
            .replacingOccurrences(of: ".", with: "")
            .uppercased()
    }
}

/// Displays a numbered stop: badge (matching the map pin), photo, name, time, and expandable note.
struct TripPlaceRowView: View {
    let place: TripDayPlace
    /// Stop number matching the map pin; nil when the place has no coordinates (not on the map).
    let number: Int?
    let badgeColor: Color
    var onTap: (() -> Void)? = nil

    @State private var isNoteExpanded = false

    private var note: String? {
        guard let note = place.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return nil }
        return note
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            numberBadge
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(place.placeName ?? "Unknown Place")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let time = TripNoteTime.time(in: note) {
                        Text(time)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(Color.mesaAccent)
                    }
                }

                if let address = place.placeAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isNoteExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)

                    if note.count > 80 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isNoteExpanded.toggle()
                            }
                        } label: {
                            Text(isNoteExpanded ? "less" : "more")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.mesaAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let addedBy = place.addedByName {
                    Text("Added by \(addedBy)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            photo
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private var numberBadge: some View {
        Text(number.map { "\($0)" } ?? "–")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(number == nil ? Color(.systemGray3) : badgeColor))
    }

    @ViewBuilder
    private var photo: some View {
        if let photoUrl = place.placePhoto, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
