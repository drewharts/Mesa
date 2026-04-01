//
//  ExploreCityChip.swift
//  loc
//
//  DUMB Component: Dismissable chip showing the active city filter on the Explore feed.
//

import SwiftUI

struct ExploreCityChip: View {
    let city: String
    let onClear: () -> Void



    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                Text(city)
                    .font(.caption)
                    .fontWeight(.medium)
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.mesaAccent)
            .clipShape(Capsule())

            Spacer()
        }
    }
}
