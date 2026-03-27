//
//  CategoryCorrectionRow.swift
//  loc
//
//  A single row in the category correction picker showing emoji, name, and selection state.
//

import SwiftUI

struct CategoryCorrectionRow: View {
    let type: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Text(PlaceTypeEmoji.emoji(for: type))
                    .font(.title3)
                Text(type)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
