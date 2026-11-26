//
//  ExploreCitySkeletonCard.swift
//  loc
//
//  DUMB Component: placeholder with the same size and corner radius as ExploreCityCard.
//

import SwiftUI

struct ExploreCitySkeletonCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(SkeletonStyle.base)
            .frame(width: ExploreCoverMetrics.city.width, height: ExploreCoverMetrics.city.height)
    }
}
