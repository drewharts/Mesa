//
//  TikToksPopupView.swift
//  loc
//

import SwiftUI

struct TikToksPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                content
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if profile.lightweightExternalPlaces.isEmpty {
                Task { await profile.loadInitialExternalPlaces() }
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
                Text("TikToks")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Text("\(profile.lightweightExternalPlaces.count) place\(profile.lightweightExternalPlaces.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var content: some View {
        if profile.isLoadingTikTokPlaces && profile.lightweightExternalPlaces.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                Text("Loading TikToks...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                Spacer()
            }
        } else if profile.lightweightExternalPlaces.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "video")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))
                Text("No TikToks Yet")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                Text("Places you add from TikTok videos will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(Array(profile.lightweightExternalPlaces.enumerated()), id: \.element.id) { index, place in
                        TikTokPopupPlaceCard(place: place, cardWidth: cardWidth, cardHeight: cardHeight)
                            .onAppear {
                                if index == profile.lightweightExternalPlaces.count - 3
                                    && profile.hasMoreExternalPlaces
                                    && !profile.isLoadingMoreExternalPlaces {
                                    Task { await profile.loadMoreExternalPlaces() }
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                if profile.isLoadingMoreExternalPlaces {
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


