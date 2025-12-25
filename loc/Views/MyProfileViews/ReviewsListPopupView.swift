//
//  ReviewsListPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated reviewed places in a popup grid
//  MVVM: Delegates data loading and state to ProfileViewModel
//  DUMB Component: Pure display, no business logic - just renders data from ViewModel

import SwiftUI

struct ReviewsListPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    // Grid layout matching ProfileView lists (consistent spacing)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                content
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if profile.lightweightReviewedPlaces.isEmpty {
                profile.loadMyReviewedPlacesWithPagination()
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(spacing: 4) {
                Text("Reviews")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Text("\(profile.lightweightReviewedPlaces.count) place\(profile.lightweightReviewedPlaces.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var content: some View {
        if profile.isLoadingReviewedPlaces && profile.lightweightReviewedPlaces.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                Text("Loading Reviews...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                Spacer()
            }
        } else if profile.lightweightReviewedPlaces.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "star.bubble")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))
                Text("No Reviews Yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                Text("Places you've reviewed will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(profile.lightweightReviewedPlaces.enumerated()), id: \.element.id) { index, place in
                        ReviewsPopupPlaceCard(place: place)
                            .onAppear {
                                if index == profile.lightweightReviewedPlaces.count - 3
                                    && profile.hasMoreReviews
                                    && !profile.isLoadingMoreReviews {
                                    Task { await profile.loadMoreMyReviews() }
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                if profile.isLoadingMoreReviews {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            }
        }
    }
}

