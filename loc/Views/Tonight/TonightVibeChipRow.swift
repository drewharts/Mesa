//
//  TonightVibeChipRow.swift
//  loc
//
//  DUMB: the single optional adjustment row on Tonight (vibe chips).
//

import SwiftUI

struct TonightVibeChipRow: View {
    let selected: TonightVibe
    let onSelect: (TonightVibe) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TonightVibe.allCases) { vibe in
                    Button { onSelect(vibe) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: vibe.symbol).font(.caption)
                            Text(vibe.label).font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundColor(vibe == selected ? .white : .primary)
                        .background(Capsule().fill(vibe == selected ? Color.primary : Color(.systemGray6)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
