//
//  GoogleMapsImportReviewView.swift
//  loc
//
//  Created by Claude on 2/9/26.
//
//  SMART View: Displays resolved places for review and list selection before import.
//  Single Responsibility: Review matched places and configure import destination.
//

import SwiftUI

/// Review screen showing matched places with selection controls and list picker.
struct GoogleMapsImportReviewView: View {
    @ObservedObject var viewModel: GoogleMapsImportViewModel
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showNewListSheet = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            placesList
            Divider()
            bottomBar
        }
        .onAppear {
            profile.ensureListsLoaded()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(matchSummaryText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                selectAllButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    private var matchSummaryText: String {
        let matched = viewModel.reviewViewModel.resolvedPlaces.filter {
            if case .matched = $0.status { return true }
            return false
        }.count
        let total = viewModel.reviewViewModel.resolvedPlaces.count
        return "\(matched) of \(total) places matched"
    }

    private var selectAllButton: some View {
        Button {
            let newState = !viewModel.reviewViewModel.allSelected
            viewModel.reviewViewModel.selectAll(newState)
        } label: {
            Text(viewModel.reviewViewModel.allSelected ? "Deselect All" : "Select All")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
    }

    // MARK: - Places List

    private var placesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.reviewViewModel.resolvedPlaces) { place in
                    GoogleMapsImportPlaceRow(place: place) {
                        viewModel.reviewViewModel.toggleSelection(for: place.id)
                    }
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            listSelectionRow
            importButton
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var listSelectionRow: some View {
        HStack {
            Text("Import to:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if let listName = viewModel.selectedListName {
                Text(listName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Menu {
                existingListsMenu
                Divider()
                Button {
                    showNewListSheet = true
                } label: {
                    Label("Create New List", systemImage: "plus")
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showNewListSheet) {
            NewListSheetView(onSave: { name in
                await viewModel.createAndSelectList(named: name, profile: profile)
            })
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
    }

    private var existingListsMenu: some View {
        ForEach(profile.lightweightPlaceLists, id: \.list_id) { list in
            Button {
                viewModel.selectList(id: list.list_id, name: list.name)
            } label: {
                Label(list.name, systemImage: viewModel.selectedListId == list.list_id ? "checkmark" : "list.bullet")
            }
        }
    }

    private var importButton: some View {
        Button {
            Task {
                guard let userId = profile.user?.id else { return }
                await viewModel.startImport(userId: userId)
            }
        } label: {
            Text("Import \(viewModel.reviewViewModel.selectedCount) Places")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canImport ? Color.blue : Color.gray)
                )
        }
        .disabled(!canImport)
    }

    private var canImport: Bool {
        viewModel.selectedListId != nil && viewModel.reviewViewModel.selectedCount > 0
    }

}
