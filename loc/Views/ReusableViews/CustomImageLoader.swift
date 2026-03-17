import SwiftUI
import Combine

struct CustomImageLoader: View {
    let urlString: String
    let contentMode: ContentMode
    let frameSize: CGSize
    let cornerRadius: CGFloat
    let onFailure: () -> Void
    
    @State private var image: UIImage? = nil
    @State private var isLoading: Bool = true
    @State private var error: Error? = nil
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: frameSize.width, height: frameSize.height)
                    .clipped()
                    .cornerRadius(cornerRadius)
                    .onAppear {
                        print("✅ [CustomImageLoader] SUCCESS: Loaded image for URL: \(urlString)")
                    }
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: frameSize.width, height: frameSize.height)
                    .cornerRadius(cornerRadius)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: frameSize.width, height: frameSize.height)
                    .cornerRadius(cornerRadius)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("Failed to load")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
                    .onAppear {
                        print("❌ [CustomImageLoader] FAILURE for URL: \(urlString)")
                        if let error = error {
                            print("❌ [CustomImageLoader] Error: \(error.localizedDescription)")
                        }
                    }
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        error = nil
        
        guard let url = URL(string: urlString) else {
            print("❌ [CustomImageLoader] Invalid URL: \(urlString)")
            isLoading = false
            error = NSError(domain: "CustomImageLoader", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            onFailure()
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "CustomImageLoader", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            guard let loadedImage = UIImage(data: data) else {
                throw NSError(domain: "CustomImageLoader", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
            }
            
            image = loadedImage
            print("✅ [CustomImageLoader] Successfully loaded image data (size: \(data.count) bytes)")
        } catch {
            print("❌ [CustomImageLoader] Load failed: \(error.localizedDescription)")
            self.error = error
            onFailure()
        }
        
        isLoading = false
    }
} 