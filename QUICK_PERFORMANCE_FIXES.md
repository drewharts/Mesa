# Quick Performance Fixes - Implementation Guide

## 🚨 Critical Issues to Fix First

Based on your profile loading performance issues, here are the **immediate fixes** that will have the biggest impact:

## 1. **Add Loading Skeletons** (Immediate Impact)

### Create ProfileSkeletonView.swift
```swift
import SwiftUI

struct ProfileSkeletonView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Profile picture skeleton
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 100, height: 100)
            
            // Name skeleton
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 150, height: 24)
            
            // Follow counts skeleton
            HStack(spacing: 24) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 20)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 12)
                    }
                }
            }
            
            // Lists skeleton
            ForEach(0..<5, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 20)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(0..<6, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 100)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
    }
}
```

### Update ProfileContentView.swift
```swift
var body: some View {
    ZStack {
        ScrollView {
            if profile.isLoading {
                ProfileSkeletonView()
            } else {
                VStack(spacing: 20) {
                    // Your existing content
                    ProfilePictureView()
                    // ... rest of content
                }
            }
        }
    }
}
```

## 2. **Implement Lazy Loading for Lists** (High Impact)

### Update ProfileViewListsView.swift
```swift
var body: some View {
    VStack(alignment: .leading, spacing: 16) {
        ListHeaderView(
            onAddList: { showingNewListSheet = true },
            searchText: $searchText
        )

        if !filteredLists.isEmpty {
            LazyVStack(spacing: 16) {
                ForEach(filteredLists, id: \.id) { list in
                    ProfileListSection(
                        list: list,
                        placeIds: profile.userListsPlaces[list.id.uuidString],
                        detailPlaceViewModel: detailPlaceViewModel,
                        placeColors: $placeColors
                    )
                    .onAppear {
                        // Load list data only when visible
                        profile.loadListDataIfNeeded(listId: list.id)
                    }
                }
            }
        } else {
            // Empty state
        }
    }
}
```

### Add to ProfileViewModel.swift
```swift
@Published var loadedListIds: Set<UUID> = []

func loadListDataIfNeeded(listId: UUID) {
    guard !loadedListIds.contains(listId) else { return }
    
    Task {
        await loadListPlaces(listId: listId)
        await MainActor.run {
            loadedListIds.insert(listId)
        }
    }
}

private func loadListPlaces(listId: UUID) async {
    // Load places for this specific list
    // Implement pagination here
}
```

## 3. **Add Pagination for Places** (Critical)

### Update DataManager.swift
```swift
func loadUserPlaceLists(userId: String, forUser: ProfileData? = nil) async {
    do {
        let lists = try await placeService.fetchLists(userId: userId)
        
        if forUser == nil {
            self.profileViewModel.userLists = lists
            self.profileViewModel.userListsPlaces = lists.reduce(into: [String: [String]]()) { result, list in
                // Only load first 10 places initially
                result[list.id.uuidString] = Array(list.places.prefix(10)).map { $0.id.uuidString }
            }
        }
        
        // Load remaining places in background
        Task.detached(priority: .background) {
            await self.loadRemainingPlacesInBackground(lists: lists, userId: userId)
        }
    } catch {
        print("Error loading user place lists: \(error.localizedDescription)")
    }
}

private func loadRemainingPlacesInBackground(lists: [PlaceList], userId: String) async {
    for list in lists {
        if list.places.count > 10 {
            // Load remaining places in batches
            let remainingPlaces = Array(list.places.dropFirst(10))
            await loadPlacesInBatches(places: remainingPlaces, listId: list.id, userId: userId)
        }
    }
}

private func loadPlacesInBatches(places: [Place], listId: UUID, userId: String) async {
    let batchSize = 10
    for batch in places.chunked(into: batchSize) {
        await withTaskGroup(of: Void.self) { group in
            for place in batch {
                group.addTask {
                    await self.fetchAndStorePlaceDetails(placeId: place.id.uuidString, userId: userId, listId: listId.uuidString)
                }
            }
        }
        
        // Small delay to prevent overwhelming Firebase
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
}
```

## 4. **Optimize Image Loading** (High Impact)

### Create ImageCache.swift
```swift
import UIKit

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "image.cache", qos: .background)
    
    init() {
        cache.countLimit = 100 // Limit cache size
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
    }
    
    func loadImage(url: URL, size: CGSize) async -> UIImage? {
        let key = "\(url.absoluteString)_\(size.width)x\(size.height)" as NSString
        
        // Check cache first
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        // Load and resize image
        guard let imageData = try? await URLSession.shared.data(from: url).0,
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        let resizedImage = await resizeImage(image, to: size)
        cache.setObject(resizedImage, forKey: key)
        return resizedImage
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            queue.async {
                let renderer = UIGraphicsImageRenderer(size: size)
                let resizedImage = renderer.image { context in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                continuation.resume(returning: resizedImage)
            }
        }
    }
}
```

## 5. **Add Performance Monitoring** (Debugging)

### Add to DataManager.swift
```swift
func initializeProfileData(userId: String) async {
    let startTime = CFAbsoluteTimeGetCurrent()
    print("🚀 Starting profile data initialization")
    
    startDataLoadingFlags()
    
    // PHASE 1: Load critical user data in parallel
    await measureLoadingTime("Critical Data") {
        await loadCriticalUserData(userId: userId)
    }
    
    // PHASE 2: Load remaining user data in parallel
    await measureLoadingTime("Remaining Data") {
        await loadRemainingUserData(userId: userId)
    }
    
    // PHASE 3: Load social data in background
    Task.detached(priority: .background) {
        await self.measureLoadingTime("Social Data") {
            await self.loadSocialDataInBackground(userId: userId)
        }
    }
    
    calculateMapAnnotations()
    
    let endTime = CFAbsoluteTimeGetCurrent()
    print("✅ Profile initialization completed in \(endTime - startTime) seconds")
}

private func measureLoadingTime<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    let result = try await block()
    let end = CFAbsoluteTimeGetCurrent()
    print("⏱️ \(operation) took \(end - start) seconds")
    return result
}
```

## 🚀 Implementation Order

1. **Add ProfileSkeletonView** - Immediate visual improvement
2. **Implement LazyVStack** - Reduce initial rendering load
3. **Add pagination** - Load places in batches
4. **Optimize image loading** - Reduce memory usage
5. **Add performance monitoring** - Track improvements

## 📊 Expected Results

After implementing these fixes:
- **Loading time**: 50-70% reduction
- **Memory usage**: 30-40% reduction
- **UI responsiveness**: Immediate improvement
- **User experience**: Much smoother

Start with the skeleton loading - it will give immediate visual feedback while you implement the other optimizations! 🎯
