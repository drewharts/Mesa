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
    @EnvironmentObject var profile: ProfileViewModel

    let place: GMSPlace

    @StateObject private var viewModel: PlaceReviewViewModel
    
    init(isPresented: Binding<Bool>, place: GMSPlace, userId: String, userName: String) {
        self._isPresented = isPresented
        self.place = place

        // Initialize the ViewModel with place/user info
        _viewModel = StateObject(
            wrappedValue: PlaceReviewViewModel(
                place: place,
                userId: userId,
                userName: userName
            )
        )
    }
    
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
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -10)


                    VStack(spacing: 8) {
                        SliderRow(title: "Food", value: $viewModel.foodRating)
                            .accessibilityIdentifier("foodSlider")
                        SliderRow(title: "Service", value: $viewModel.serviceRating)
                            .accessibilityIdentifier("serviceSlider")
                        SliderRow(title: "Ambience", value: $viewModel.ambienceRating)
                            .accessibilityIdentifier("ambienceSlider")
                    }
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 10)
                        .padding(.horizontal, -20)
                    
                    UpvoteFavDishesView(favoriteDishes: $viewModel.favoriteDishes) // Pass the binding here
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -10)


                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.reviewText)
                            .font(.subheadline)
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .background(.gray.opacity(0.3))
                            .cornerRadius(8)
                            .foregroundStyle(.black)

                        if viewModel.reviewText.isEmpty {
                            Text("Add a review...")
                                .font(.subheadline)
                                .foregroundColor(.black)
                                .font(.footnote)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -10)
                    
                    //upload photos
                    HStack(alignment: .center) {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                            .padding(8)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                        Text("Upload photos")
                            .foregroundColor(.black)
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .padding(.top, 15)
                        .padding(.bottom, 15)
                        .padding(.horizontal, -10)


                    Button(action: {
                        viewModel.submitReview { success in
                            if success {
                                isPresented = false
                            }
                        }
                    }) {
                        Text("POST REVIEW")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.black)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 40)
            }
            .background(Color(.white))
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: btnBack)
    }
}

struct UpvoteFavDishesView: View {
    @Binding var favoriteDishes: [String]
    @State private var showTextField: Bool = false
    @State private var newDish: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upvote favorite dishes")
                .font(.footnote)
                .foregroundStyle(.black)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(favoriteDishes, id: \.self) { dish in
                        Text(dish)
                            .font(.footnote)
                            .foregroundStyle(.black)
                            .padding(8)
                            .background(Capsule().fill(Color.gray.opacity(0.2)))
                            .onTapGesture {
                                if let index = favoriteDishes.firstIndex(of: dish) {
                                    favoriteDishes.remove(at: index)
                                }
                            }
                    }

                    if favoriteDishes.count < 3 {
                        if showTextField {
                            TextField("Add dish", text: $newDish)
                                .padding(8)
                                .background(Capsule().fill(Color.gray.opacity(0.2)))
                                .foregroundStyle(.black)
                                .onSubmit {
                                    if !newDish.isEmpty {
                                        favoriteDishes.append(newDish)
                                        newDish = ""
                                        showTextField = false
                                        isTextFieldFocused = false // Unfocus after submit
                                    }
                                }
                                .onDisappear {
                                    showTextField = false
                                    isTextFieldFocused = false
                                }
                                .focused($isTextFieldFocused) // Bind the FocusState
                        }

                        if !showTextField {
                            Button(action: {
                                showTextField = true
                                isTextFieldFocused = true // Focus after showing
                            }) {
                                Image(systemName: "plus")
                                    .foregroundColor(.black)
                                    .padding(8)
                                    .background(Circle().fill(Color.gray.opacity(0.2)))
                            }
                        }
                    }
                }
            }
        }
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

                    // Thumb with Number
                    ZStack {
                        Circle()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.black)
                        
                        Text(String(format: "%.00f", value)) // Display the value
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
