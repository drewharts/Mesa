//
//  ListSettingsSheet.swift
//  loc
//
//  Sheet UI for managing list settings including privacy toggle and pricing.
//

import SwiftUI

struct ListSettingsSheet: View {
    @StateObject private var settingsViewModel: ListSettingsViewModel
    @StateObject private var pricingViewModel: ListPricingViewModel
    @Environment(\.dismiss) private var dismiss

    let onSave: ((Bool, String?) -> Void)?

    init(
        listId: String,
        initialIsPublic: Bool,
        currentPriceTier: String? = nil,
        onSave: ((Bool, String?) -> Void)? = nil
    ) {
        _settingsViewModel = StateObject(wrappedValue: ListSettingsViewModel(
            listId: listId,
            initialIsPublic: initialIsPublic
        ))
        _pricingViewModel = StateObject(wrappedValue: ListPricingViewModel(
            listId: listId,
            currentPriceTier: currentPriceTier
        ))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                privacySection
                pricingSection
            }
            .navigationTitle("List Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    settingsViewModel.errorMessage = nil
                    pricingViewModel.errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    /// Privacy toggle section
    private var privacySection: some View {
        Section {
            Toggle("Private List", isOn: Binding(
                get: { !settingsViewModel.isPublic },
                set: { newValue in
                    settingsViewModel.isPublic = !newValue
                    // Paid lists must be public
                    if !settingsViewModel.isPublic && pricingViewModel.isPaid {
                        pricingViewModel.isPaid = false
                    }
                }
            ))
            .disabled(isSaving)
        } footer: {
            Text("Private lists only show places on the map for you and collaborators.")
        }
    }

    /// Pricing configuration section (only for public lists)
    private var pricingSection: some View {
        Section {
            if settingsViewModel.isPublic {
                ListPricingPickerView(viewModel: pricingViewModel)
            } else {
                Text("Paid lists must be public")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        } header: {
            Text("Pricing")
        } footer: {
            if settingsViewModel.isPublic && pricingViewModel.isPaid {
                Text("Buyers will see a preview of \(pricingViewModel.selectedTier.displayPrice) and pay to unlock all places.")
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether either save operation is in progress
    private var isSaving: Bool {
        settingsViewModel.isSaving || pricingViewModel.isSaving
    }

    /// First non-nil error from either view model
    private var errorMessage: String? {
        settingsViewModel.errorMessage ?? pricingViewModel.errorMessage
    }

    // MARK: - Actions

    /// Saves both privacy and pricing settings
    private func save() async {
        let privacySaved = await settingsViewModel.savePrivacySetting()
        guard privacySaved else { return }

        let pricingSaved = await pricingViewModel.savePricing()
        guard pricingSaved else { return }

        let savedTier = pricingViewModel.isPaid ? pricingViewModel.selectedTier.rawValue : nil
        onSave?(settingsViewModel.isPublic, savedTier)
        dismiss()
    }
}

#Preview {
    ListSettingsSheet(
        listId: "test-id",
        initialIsPublic: true
    )
}
