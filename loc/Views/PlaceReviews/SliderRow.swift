//
//  SliderRow.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//

import SwiftUI

struct SliderRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.footnote)
                .foregroundColor(.black)
                .padding(.bottom, 5) // Add some space between the title and the slider

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .frame(width: geometry.size.width, height: 10)
                        .foregroundColor(.gray.opacity(0.3))
                        .cornerRadius(5)

                    // Filled track
                    Rectangle()
                        .frame(width: geometry.size.width * CGFloat(value / 10.0), height: 10)
                        .foregroundColor(.black)
                        .cornerRadius(5)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged({ value in
                                self.value = min(10.0, max(0.0, Double(value.location.x / geometry.size.width * 10.0)))
                            })
                        )

                    // Thumb with Number
                    ZStack {
                        Circle()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.black)
                        
                        Text(String(format: "%.1f", value)) // Display the value
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .offset(x: geometry.size.width * CGFloat(value / 10.0) - 10) // -10 to center the thumb
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged({ value in
                            self.value = min(10.0, max(0.0, Double(value.location.x / geometry.size.width * 10.0)))
                        })
                    )
                } // End of ZStack
                .frame(height: 10)
            }
            .frame(height: 20) // Fixed height for the slider

            HStack {
                Text("0")
                    .font(.footnote)
                    .foregroundColor(.black)
                Spacer()
                Text("10")
                    .font(.footnote)
                    .foregroundColor(.black)
            }
        }
    }
}
