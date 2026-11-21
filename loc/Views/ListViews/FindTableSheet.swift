//
//  FindTableSheet.swift
//  loc
//
//  DUMB Component: compact sheet to pick party size, day and time window before searching a list for tables.
//  Reads and forwards everything through FindTableViewModel; it never books anything.
//

import SwiftUI

struct FindTableSheet: View {
    @ObservedObject var viewModel: FindTableViewModel
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find a table")
                .font(.title3.weight(.bold))

            Stepper(value: $viewModel.partySize, in: FindTableViewModel.partySizeRange) {
                Text(viewModel.partySize == 1 ? "1 guest" : "\(viewModel.partySize) guests")
                    .font(.body.weight(.medium))
            }

            HStack(spacing: 8) {
                ForEach(FindTableViewModel.Preset.allCases) { preset in
                    FilterChip(label: preset.rawValue, isSelected: viewModel.preset == preset, onTap: { viewModel.selectPreset(preset) })
                }
            }

            if viewModel.preset == .pick {
                pickers
            } else {
                Text(viewModel.selectionSummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(action: onSearch) {
                Text("Search")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Capsule().fill(Color.mesaAccent.opacity(viewModel.canSearch ? 1 : 0.4)))
            }
            .disabled(!viewModel.canSearch)
        }
        .padding(20)
        .presentationDetents([.height(viewModel.preset == .pick ? 420 : 320)])
        .presentationDragIndicator(.visible)
    }

    private var pickers: some View {
        VStack(spacing: 4) {
            DatePicker("Date", selection: Binding(get: { viewModel.selection.date }, set: { viewModel.setDate($0) }),
                       in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
            DatePicker("From", selection: Binding(get: { viewModel.date(forMinutes: viewModel.selection.window.startMinutes) },
                                                  set: { viewModel.setStart($0) }),
                       displayedComponents: .hourAndMinute)
            DatePicker("Until", selection: Binding(get: { viewModel.date(forMinutes: viewModel.selection.window.endMinutes) },
                                                   set: { viewModel.setEnd($0) }),
                       displayedComponents: .hourAndMinute)
        }
    }
}
