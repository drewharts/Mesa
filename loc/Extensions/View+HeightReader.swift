//
//  View+HeightReader.swift
//  loc
//
//  Reports a view's laid-out height to a binding via a preference key.
//

import SwiftUI

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension View {
    /// Writes this view's height into the given binding whenever it changes.
    func readHeight(into height: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: ViewHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self) { height.wrappedValue = $0 }
    }
}
