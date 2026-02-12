//  CreatePlaceDescriptionField.swift
//  loc

import SwiftUI

struct CreatePlaceDescriptionField: View {
    @Binding var placeDescription: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description (optional)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $placeDescription)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )

                if placeDescription.isEmpty {
                    Text("Describe this place...")
                        .foregroundColor(Color(.placeholderText))
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
