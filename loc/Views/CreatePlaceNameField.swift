//  CreatePlaceNameField.swift
//  loc

import SwiftUI

struct CreatePlaceNameField: View {
    @Binding var placeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextField("Enter place name", text: $placeName)
                .font(.body)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
    }
}
