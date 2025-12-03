//
//  ProfileTikToksView.swift
//  loc
//

import SwiftUI

struct ProfileTikToksView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showingTikToksPopup = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIKTOKS")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            tiktoksCard
            
            Divider()
                .padding(.horizontal, 20)
        }
        .onAppear {
            if profile.lightweightExternalPlaces.isEmpty && !profile.isLoadingTikTokPlaces {
                Task { await profile.loadInitialExternalPlaces() }
            }
        }
        .sheet(isPresented: $showingTikToksPopup) {
            TikToksPopupView()
        }
    }
    
    private var tiktoksCard: some View {
        Button(action: { showingTikToksPopup = true }) {
            VStack(spacing: 0) {
                if profile.isLoadingTikTokPlaces {
                    loadingState
                } else if profile.lightweightExternalPlaces.isEmpty {
                    emptyState
                } else {
                    tiktoksGrid
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
    }
    
    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading TikToks...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No TikToks yet")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Add places from TikTok videos to see them here")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
    
    private var tiktoksGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(profile.lightweightExternalPlaces.prefix(6)) { place in
                TikTokPlaceCard(place: place)
            }
            
            // Fill remaining slots
            ForEach(0..<max(0, 6 - profile.lightweightExternalPlaces.count), id: \.self) { _ in
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 80)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(16)
    }
}

