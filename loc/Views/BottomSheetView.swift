//
//  BottomSheetView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI

struct BottomSheetView<Content: View>: View {
    @Binding var sheetHeight: CGFloat
    let maxSheetHeight: CGFloat
    @GestureState private var dragOffset: CGFloat = 0
    let content: Content

    init(sheetHeight: Binding<CGFloat>, maxSheetHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self._sheetHeight = sheetHeight
        self.maxSheetHeight = maxSheetHeight
        self.content = content()
    }

    var body: some View {
        VStack {
            Spacer()
            VStack {
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 80, height: 6)
                    .padding(.top, 8)
                content
                    .frame(maxWidth: .infinity)
                    .padding(.top,8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: sheetHeight)
            .background(Color.white)
            .cornerRadius(30)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        let newHeight = sheetHeight - value.translation.height
                        if newHeight <= maxSheetHeight && newHeight >= 100 {
                            state = value.translation.height
                        }
                    }
                    .onEnded { value in
                        let newHeight = sheetHeight - value.translation.height
                        if newHeight > maxSheetHeight * 0.75 {
                            withAnimation {
                                sheetHeight = maxSheetHeight
                            }
                        } else if newHeight > maxSheetHeight * 0.5 {
                            withAnimation {
                                sheetHeight = maxSheetHeight * 0.5
                            }
                        } else {
                            sheetHeight = 100
                        }
//                        if newHeight > maxSheetHeight * 0.5 {
//                            withAnimation {
//                                sheetHeight = maxSheetHeight
//                            }
//                        } else {
//                            sheetHeight = 100
//                        }
                    }
            )
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}
