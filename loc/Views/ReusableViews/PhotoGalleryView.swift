import SwiftUI

struct PhotoGalleryView: View {
    let photos: [UIImage]
    let initialIndex: Int
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int
    
    init(photos: [UIImage], initialIndex: Int, isPresented: Binding<Bool>) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    isPresented = false
                }
            
            VStack {
                // Header with close button and photo counter
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding()
                    }
                    
                    Spacer()
                    
                    if photos.count > 1 {
                        Text("\(currentIndex + 1) of \(photos.count)")
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Photo display with TabView for swiping
                if photos.count > 1 {
                    TabView(selection: $currentIndex) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            ZoomableImageView(image: photos[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .padding()
                } else if photos.count == 1 {
                    ZoomableImageView(image: photos[0])
                        .padding()
                }
                
                Spacer()
                
                // Page indicators for multiple photos
                if photos.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentIndex)
        .transition(.opacity)
    }
} 