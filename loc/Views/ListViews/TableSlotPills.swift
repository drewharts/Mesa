//
//  TableSlotPills.swift
//  loc
//
//  DUMB Component: a horizontally scrolling row of bookable time pills under a place tile.
//  Tapping a pill hands off to the booking page; nothing is booked in-app.
//

import SwiftUI

struct TableSlotPills: View {
    let slots: [TableSlot]
    let timeText: (Int) -> String
    let onTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(slots) { slot in
                    Button(action: onTap) {
                        Text(slot.minutes.map(timeText) ?? slot.time)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.mesaAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.mesaAccent.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
