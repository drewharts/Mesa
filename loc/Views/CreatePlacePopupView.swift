import SwiftUI
import CoreLocation

struct CreatePlacePopupView: View {
    @Binding var isPresented: Bool
    @Binding var placeName: String
    @Binding var placeDescription: String
    let coordinate: CLLocationCoordinate2D
    let onCreatePlace: (String, String?) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
                .padding(.trailing)
            }
            .padding(.top)
            
            // Place name input
            VStack(alignment: .leading, spacing: 8) {  
                TextField("Enter place name", text: $placeName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textFieldStyle(PlainTextFieldStyle())

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $placeDescription)
                        .frame(height: 100)
                        .padding(1)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .font(.subheadline)
                    
                    if placeDescription.isEmpty {
                        Text("Enter description (optional)")
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            
            // Create button
            Button(action: {
                onCreatePlace(placeName, placeDescription.isEmpty ? nil : placeDescription)
                isPresented = false
            }) {
                Text("Create Place")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(placeName.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(placeName.isEmpty)
            .padding(.horizontal)
            .padding(.top, 30)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 5)
        .padding()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        @State private var placeName = ""
        @State private var placeDescription = ""
        
        var body: some View {
            ZStack {
                Color.gray.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                CreatePlacePopupView(
                    isPresented: $isPresented,
                    placeName: $placeName,
                    placeDescription: $placeDescription,
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                ) { name, description in
                    print("Created place: \(name)")
                    if let description = description {
                        print("Description: \(description)")
                    }
                }
            }
        }
    }
    
    return PreviewWrapper()
} 
