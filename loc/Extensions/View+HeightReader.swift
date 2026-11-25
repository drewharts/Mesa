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

private struct ViewTopKey: PreferenceKey {
    static var defaultValue: CGFloat = .nan
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if !next.isNaN { value = next }
    }
}

extension View {
    /// Writes this view's top edge in global (screen) coordinates into the given binding whenever it changes.
    func readGlobalTop(into top: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: ViewTopKey.self, value: proxy.frame(in: .global).minY)
            }
        )
        .onPreferenceChange(ViewTopKey.self) { if !$0.isNaN { top.wrappedValue = $0 } }
    }
}
