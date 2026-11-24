//
//  TabSheetContainer.swift
//  loc
//
//  DUMB Component: a bottom sheet laid over the map (Google/Apple Maps style) that hosts a tab's
//  content. It rests at the medium or large detent chosen by `TabSheetViewModel`, can be dragged
//  between them by its grabber, and slides out of view when not presented. It is not a system
//  sheet, so the tab bar stays visible and the map's own sheets are unaffected.
//

import SwiftUI

struct TabSheetContainer<Content: View>: View {
    @ObservedObject var viewModel: TabSheetViewModel
    let isPresented: Bool
    @ViewBuilder let content: () -> Content

    @GestureState private var dragTranslation: CGFloat = 0

    private let cornerRadius: CGFloat = 24
    private let minimumHeight: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            sheet(containerHeight: proxy.size.height)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .clipped()
    }

    // MARK: - Subviews

    private func sheet(containerHeight: CGFloat) -> some View {
        let resting = viewModel.detent.height(in: containerHeight)
        let height = min(max(resting - dragTranslation, minimumHeight), containerHeight)
        return VStack(spacing: 0) {
            grabber(containerHeight: containerHeight)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(Color(.systemBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: -2)
        .offset(y: isPresented ? 0 : height + 40)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: isPresented)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: viewModel.detent)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: dragTranslation == 0)
        .allowsHitTesting(isPresented)
        .accessibilityHidden(!isPresented)
    }

    private func grabber(containerHeight: CGFloat) -> some View {
        Capsule()
            .fill(Color(.systemGray3))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(dragGesture(containerHeight: containerHeight))
    }

    private func dragGesture(containerHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                viewModel.settle(
                    afterDragTranslation: value.translation.height,
                    predictedTranslation: value.predictedEndTranslation.height,
                    containerHeight: containerHeight
                )
            }
    }
}

extension View {
    /// Keeps a tab's view alive inside the sheet but invisible and untouchable while another tab is showing.
    func tabLayer(isActive: Bool) -> some View {
        opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }
}
