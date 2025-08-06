//  ReviewTypeSelectionView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI

struct ReviewTypeSelectionView: View {
    @ObservedObject var photoImportVM: PhotoImportViewModel
    @Environment(\.presentationMode) var presentationMode
    let onGenericReview: () -> Void
    let onRestaurantReview: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("📝 Choose Review Type")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    if let selectedPlace = photoImportVM.selectedPlace {
                        Text("for \(selectedPlace.properties.name)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)
                
                // Photo Preview
                if !photoImportVM.selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<photoImportVM.selectedImages.count, id: \.self) { index in
                                Image(uiImage: photoImportVM.selectedImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 110)
                    
                    if photoImportVM.selectedImages.count > 1 {
                        Text("\(photoImportVM.selectedImages.count) photos selected")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Review Type Options
                VStack(spacing: 16) {
                    // Restaurant Review Button
                    Button(action: {
                        onRestaurantReview()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Restaurant Review")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                
                                Text("Rate food, service, and atmosphere")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Generic Review Button
                    Button(action: {
                        onGenericReview()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "star.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Generic Review")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                
                                Text("Simple rating and comments")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Cancel Button
                Button("Cancel") {
                    photoImportVM.showReviewTypeSelection = false
                    // Clear the selection since user cancelled the flow
                    photoImportVM.clearSelection()
                }
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
} 