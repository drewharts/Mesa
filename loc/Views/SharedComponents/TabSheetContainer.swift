//
//  TabSheetContainer.swift
//  loc
//
//  DUMB Component: a bottom sheet laid over the map (Google/Apple Maps style) that hosts a tab's
//  content. It rests at the medium or large detent chosen by `TabSheetViewModel`, can be dragged
//  between them by dragging its fixed header strip (grabber + compact title; or all the way down to dismiss it), and slides
//  out of view when not presented. The strip never scrolls, so dragging it can't be mistaken for scrolling the content. It is
//  not a system sheet, so the tab bar stays visible and the map's own sheets are unaffected.
//

import SwiftUI

struct TabSheetContainer<Content: View>: View {
    @ObservedObject var viewModel: TabSheetViewModel
    let isPresented: Bool
    /// Compact title shown in the fixed header strip under the grabber.
    let title: String
    /// When true and a destination is pushed (`viewModel.pushedHeader`), the strip shows that header instead of `title`.
    var showsPushedHeader: Bool = false
    /// Extra space kept clear at the bottom of the content (e.g. the tab bar plus margin) so the last item is reachable.
    var bottomInset: CGFloat = 0
    /// Called when the user drags the sheet down far enough to hide it completely.
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    @GestureState private var dragTranslation: CGFloat = 0

    private let cornerRadius: CGFloat = 24
    private let minimumHeight: CGFloat = 60
    private let headerHeight: CGFloat = 60
    private let pushedDetailHeaderHeight: CGFloat = 90

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
            header(containerHeight: containerHeight)
            content()
                .safeAreaPadding(.bottom, bottomInset)
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

    private func header(containerHeight: CGFloat) -> some View {
        let pushed = showsPushedHeader ? viewModel.pushedHeader : nil
        return VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            ZStack(alignment: .topLeading) {
                if let pushed {
                    TabSheetHeaderContent(header: pushed)
                        .id(pushed.id)
                        .transition(.opacity.combined(with: .offset(x: 12)))
                } else {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .padding(.horizontal, 16)
                        .accessibilityAddTraits(.isHeader)
                        .transition(.opacity)
                }
            }
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            Spacer(minLength: 0)
        }
        .frame(height: pushed?.hasDetailLine == true ? pushedDetailHeaderHeight : headerHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: pushed?.id)
        .gesture(dragGesture(containerHeight: containerHeight))
    }

    private func dragGesture(containerHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let shouldDismiss = viewModel.settle(
                    afterDragTranslation: value.translation.height,
                    predictedTranslation: value.predictedEndTranslation.height,
                    containerHeight: containerHeight
                )
                if shouldDismiss { onDismiss() }
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
