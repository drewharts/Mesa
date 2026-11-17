//
//  SavedLibraryEntryRow.swift
//  loc
//
//  Entry row on the user's own profile. Hidden only when the SavedLibraryGate kill switch is set.
//

import SwiftUI

struct SavedLibraryEntryRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 20))
                .foregroundColor(.mesaAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Saved")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("All your places, one list per city")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}
