//
//  ProfileListDescription.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct ProfileListDescription: View {
    @State var list: PlaceList
    @State private var showingPlacesPopup = false
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var placeColors: [UUID: Color]
    
    var body: some View {
        Button(action: {
            // Set list filter and navigate to map
            profile.selectedListIdForMap = list.id.uuidString
            // Dismiss profile view to show map
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Text(list.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .padding(.leading, 20)
                
                Text("\(profile.placeListCounts[list.id] ?? 0) \(profile.placeListCounts[list.id] == 1 ? "place" : "places")")
                    .font(.caption)
                    .foregroundStyle(.black)
                
                Spacer()
            }
        }
    }
}
