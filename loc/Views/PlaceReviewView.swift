//
//  PlaceReviewView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/13/25.
//

import SwiftUI
import GooglePlaces

struct PlaceReviewView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @Binding var isPresented: Bool
    let place: GMSPlace

    @State private var foodRating: Double = 0
    @State private var serviceRating: Double = 0
    @State private var ambienceRating: Double = 0
    @State private var favoriteDishes: [String] = []
    @State private var reviewText: String = ""
    @State private var isReviewTextEmpty: Bool = true
    
    var btnBack : some View { Button(action: {
        self.presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
            Image(systemName: "chevron.left") // set image here
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.black)
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text(place.name ?? "Unnamed Place")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    Text("Your Review")
                        .font(.footnote)
                        .foregroundStyle(.black)
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -20)


                    VStack(spacing: 8) {
                        SliderRow(title: "FOOD", value: $foodRating)
                            .accessibilityIdentifier("foodSlider")
                        SliderRow(title: "SERVICE", value: $serviceRating)
                            .accessibilityIdentifier("serviceSlider")
                        SliderRow(title: "AMBIENCE", value: $ambienceRating)
                            .accessibilityIdentifier("ambienceSlider")
                    }
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                        .padding(.horizontal, -20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UPVOTE FAVORITE DISHES")
                            .font(.footnote)
                            .foregroundStyle(.black)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(favoriteDishes, id: \.self) { dish in
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
                                        .foregroundColor(.black)
                                        .padding(8)
                                        .background(Circle().fill(Color.gray.opacity(0.2)))
                                }
                            }
                        }
                    }
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -20)


                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $reviewText)
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .background(.gray.opacity(0.3))
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                            .onChange(of: reviewText) {
                                isReviewTextEmpty = reviewText.isEmpty
                            }

                        if isReviewTextEmpty {
                            Text("Add a review")
                                .foregroundColor(.black)
                                .font(.footnote)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -20)


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
                .padding(.horizontal, 50)
            }
            .background(Color(.white))
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
    }
}


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

                    // Thumb
                    Circle()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.black)
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
