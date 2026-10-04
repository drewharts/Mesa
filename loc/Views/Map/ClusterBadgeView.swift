//
//  ClusterBadgeView.swift
//  loc
//
//  Cluster bubble content rendered into a static image for GMUCluster marker pins.
//

import SwiftUI

/// White circle with a bold count label, matching the same white-circle-plus-shadow look used
/// by every other marker in the app (emoji pins, community pins, trip pins) rather than a
/// solid-colored bubble, which reads as an out-of-place, generic "map SDK default" style.
struct ClusterBadgeView: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.blue)
        }
    }
}
