//
//  TripContributorsStepView.swift
//  loc
//
//  Third step of trip creation - add collaborators
//

import SwiftUI

/// Search and select contributors for the trip.
struct TripContributorsStepView: View {
    @EnvironmentObject var userSession: UserSession
    @ObservedObject var viewModel: CreateTripViewModel

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        VStack(spacing: 16) {
            Text("Who's coming?")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 16)

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by name...", text: $viewModel.contributorSearchText)
                    .textFieldStyle(.plain)
                if !viewModel.contributorSearchText.isEmpty {
                    Button {
                        viewModel.clearContributorSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

            // Selected contributors chips
            if !viewModel.selectedContributors.isEmpty {
                selectedChips
            }

            // Search results or empty state
            if viewModel.isSearchingContributors {
                ProgressView()
                    .padding()
            } else if !viewModel.contributorSearchResults.isEmpty {
                searchResultsList
            }

            Spacer()

            // Create Trip button
            Button {
                Task {
                    if let userId = userSession.currentUserId {
                        await viewModel.createTrip(ownerId: userId)
                    }
                }
            } label: {
                Text("Create Trip")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(mesaCharcoal))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Selected Chips

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.selectedContributors) { user in
                    HStack(spacing: 6) {
                        if let url = user.profilePhotoURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        }

                        Text(user.firstName)
                            .font(.subheadline)

                        Button {
                            viewModel.removeContributor(user)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.contributorSearchResults) { user in
                    Button {
                        viewModel.selectContributor(user)
                    } label: {
                        HStack(spacing: 12) {
                            if let url = user.profilePhotoURL {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(.gray.opacity(0.5))
                            }

                            Text(user.fullName)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "plus.circle")
                                .foregroundColor(mesaCharcoal)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 64)
                }
            }
        }
    }
}
