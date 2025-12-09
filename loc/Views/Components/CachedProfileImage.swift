//
//  CachedProfileImage.swift
//  loc
//
//  DUMB Component: Displays a cached profile image with proper loading states
//  Single Responsibility: Load, cache, and display profile images
//
//  Uses ImageCacheService for memory + disk caching to prevent re-downloads
//

import SwiftUI

struct CachedProfileImage: View {
    let url: String?
    let size: CGFloat
    let fallbackInitial: String
    var fallbackColor: Color = Color.gray.opacity(0.3)
    var fallbackTextColor: Color = .gray
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    
    private let imageCache = ImageCacheService.shared
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                loadingView
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: url) {
            await loadImage()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        Circle()
            .fill(fallbackColor)
            .overlay(
                ProgressView()
                    .scaleEffect(0.5)
            )
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(fallbackColor)
            .overlay(
                Text(fallbackInitial)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(fallbackTextColor)
            )
    }
    
    // MARK: - Image Loading
    
    private func loadImage() async {
        // Reset state
        loadedImage = nil
        hasFailed = false
        
        // Validate URL
        guard let urlString = url,
              !urlString.isEmpty,
              let imageURL = URL(string: urlString) else {
            hasFailed = true
            return
        }
        
        // Check cache first (fast path)
        if let cachedImage = imageCache.getImage(for: imageURL) {
            loadedImage = cachedImage
            return
        }
        
        // Not in cache - fetch from network
        isLoading = true
        defer { isLoading = false }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: imageURL)
            
            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                hasFailed = true
                return
            }
            
            // Cache and display
            imageCache.storeImage(image, for: imageURL)
            
            await MainActor.run {
                loadedImage = image
            }
        } catch {
            hasFailed = true
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        // Valid image (will show placeholder then load)
        CachedProfileImage(
            url: "https://example.com/photo.jpg",
            size: 40,
            fallbackInitial: "S"
        )
        
        // No URL (will show placeholder)
        CachedProfileImage(
            url: nil,
            size: 40,
            fallbackInitial: "?"
        )
        
        // Empty URL (will show placeholder)
        CachedProfileImage(
            url: "",
            size: 40,
            fallbackInitial: "A"
        )
    }
    .padding()
}

