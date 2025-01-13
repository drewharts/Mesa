//
//  PlaceReviewView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/13/25.
//

import SwiftUI

struct PlaceReviewView: View {
    @Binding var isPresented: Bool

    @State private var foodRating: Double = 0
    @State private var serviceRating: Double = 0
    @State private var ambienceRating: Double = 0
    @State private var favoriteDishes: [String] = []
    @State private var reviewText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Review")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .foregroundColor(.red)
                }
            }

            VStack(spacing: 8) {
                SliderRow(title: "Food", value: $foodRating)
                SliderRow(title: "Service", value: $serviceRating)
                SliderRow(title: "Ambience", value: $ambienceRating)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Upvote Favorite Dishes")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(favoriteDishes, id: \..self) { dish in
                            Text(dish)
                                .padding(8)
                                .background(Capsule().fill(Color.gray.opacity(0.2)))
                                .onTapGesture {
                                    favoriteDishes.removeAll { $0 == dish }
                                }
                        }
                        Button(action: {
                            favoriteDishes.append("New Dish") // Replace with actual input logic
                        }) {
                            Image(systemName: "plus")
                                .padding(8)
                                .background(Circle().fill(Color.gray.opacity(0.2)))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add a Review")
                    .font(.headline)
                TextEditor(text: $reviewText)
                    .frame(height: 100)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            Button(action: { isPresented = false }) {
                Text("Post Review")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding()
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            Slider(value: $value, in: 0...10, step: 0.1)
            Text(String(format: "%.1f", value))
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}
