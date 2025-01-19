//
//  UpvoteFavDishesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//

import SwiftUI
import GooglePlaces

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
