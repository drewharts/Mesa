//
//  PlanGroupPickView.swift
//  loc
//
//  "Plan for later": one screen to start a ranked group pick for a future date.
//  Smart defaults so it's usually 1 tap: next Friday 7:30 PM, voting closes the
//  day before, top 3 suggestions preselected, title from the vibe.
//  More places come from suggestions or a search of your & friends' saves;
//  the live pick sheet can still add/invite after creating.
//

import SwiftUI

struct PlanGroupPickView: View {
    @ObservedObject var viewModel: TonightViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var hasDate = true
    @State private var eventAt = PlanGroupPickView.defaultEventDate()
    @State private var customDeadline = false
    @State private var decideAt = Date()
    @State private var selected: [String] = []   // place ids in pick order
    @State private var query = ""
    @State private var failed = false
    @State private var didSeed = false

    init(viewModel: TonightViewModel) {
        self.viewModel = viewModel
        _title = State(initialValue: "Dinner plans")
    }

    /// Next Friday at 7:30 PM (or Friday next week if it's already Friday evening).
    static func defaultEventDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        var c = DateComponents(); c.weekday = 6; c.hour = 19; c.minute = 30
        return calendar.nextDate(after: now.addingTimeInterval(3 * 3600), matching: c, matchingPolicy: .nextTime) ?? now.addingTimeInterval(86400 * 3)
    }

    /// Default deadline: the day before the event (at least 1 hour from now), or 24h without a date.
    private var autoDeadline: Date {
        let floor = Date().addingTimeInterval(3600)
        guard hasDate else { return Date().addingTimeInterval(86400) }
        let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: eventAt) ?? eventAt
        return min(max(dayBefore, floor), eventAt)
    }

    /// Valid deadline window; never inverted even if the event is very soon.
    private var deadlineRange: ClosedRange<Date> {
        let lower = Date().addingTimeInterval(900)
        let upper = hasDate ? eventAt : Date().addingTimeInterval(86400 * 60)
        return lower...max(lower, upper)
    }

    private var effectiveDeadline: Date { customDeadline ? decideAt : autoDeadline }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What's the plan?", text: $title)
                    Toggle("Pick a date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("When", selection: $eventAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    }
                    if customDeadline {
                        DatePicker("Voting closes", selection: $decideAt, in: deadlineRange,
                                   displayedComponents: [.date, .hourAndMinute])
                    } else {
                        Button {
                            decideAt = autoDeadline
                            customDeadline = true
                        } label: {
                            HStack {
                                Text("Voting closes").foregroundColor(.primary)
                                Spacer()
                                Text((hasDate ? "Day before · " : "") + autoDeadline.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Everyone ranks their top 3. 1st = 3 pts, 2nd = 2, 3rd = 1. Results are live and lock when voting closes.")
                }

                Section("Options · \(selected.count) picked") {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search your & friends' saves", text: $query)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    ForEach(rows) { row in
                        Button { toggle(row.placeId) } label: { rowLabel(row) }
                            .buttonStyle(.plain)
                    }
                    if rows.isEmpty {
                        Text(query.isEmpty ? "Save a few places and they'll show up here." : "No saved place matches that.")
                            .foregroundColor(.secondary)
                    }
                }

                if failed {
                    Text("Couldn't create the plan. Update Mesa or try again in a bit.")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Plan for later")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSharing {
                        ProgressView()
                    } else {
                        Button("Share") { Task { await create() } }
                            .disabled(selected.count < 2)
                    }
                }
            }
        }
        .onAppear(perform: seed)
    }

    /// Search results while typing, otherwise suggestions plus anything already picked.
    private var rows: [PlanCandidate] {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return viewModel.searchSaved(query) }
        var list = viewModel.planSuggestions
        let shown = Set(list.map(\.id))
        list += extraSelected.filter { !shown.contains($0.id) }
        return list
    }

    @State private var extraSelected: [PlanCandidate] = []

    private func seed() {
        guard !didSeed else { return }
        didSeed = true
        title = viewModel.vibe.headline.isEmpty ? "Dinner plans" : viewModel.vibe.headline
        selected = viewModel.planSuggestions.prefix(3).map(\.placeId)
    }

    private func toggle(_ placeId: String) {
        if let i = selected.firstIndex(where: { $0.lowercased() == placeId.lowercased() }) {
            selected.remove(at: i)
        } else if selected.count < GroupPickViewModel.maxPlaces {
            selected.append(placeId)
            if let row = viewModel.searchSaved(query).first(where: { $0.placeId == placeId }) {
                extraSelected.append(row)
            }
            query = ""
        }
    }

    private func rowLabel(_ row: PlanCandidate) -> some View {
        let isOn = selected.contains { $0.lowercased() == row.placeId.lowercased() }
        return HStack(spacing: 12) {
            TonightPlaceThumbnail(place: row.place, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.place.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                if let address = row.place.address {
                    Text(address).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isOn ? .primary : .secondary)
        }
        .contentShape(Rectangle())
    }

    private func create() async {
        failed = false
        let ok = await viewModel.createPlannedPick(
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Dinner plans" : title,
            placeIds: selected,
            eventAt: hasDate ? eventAt : nil,
            decideAt: effectiveDeadline)
        if ok { dismiss() } else { failed = true }
    }
}
