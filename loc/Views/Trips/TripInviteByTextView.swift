//
//  TripInviteByTextView.swift
//  loc
//
//  View for inviting non-users to a trip via SMS
//

import SwiftUI

/// Phone number input and pending invitations list for SMS trip invites.
struct TripInviteByTextView: View {
    @ObservedObject var viewModel: TripInviteViewModel

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        VStack(spacing: 16) {
            phoneInputSection
            pendingInvitationsSection
        }
        .task {
            await viewModel.loadPendingInvitations()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.error ?? "Something went wrong")
        }
    }

    // MARK: - Phone Input

    private var phoneInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invite by Phone Number")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(.secondary)
                    TextField("Phone number", text: $viewModel.phoneInput)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    Task {
                        await viewModel.prepareInvitation()
                    }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.body)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(mesaCharcoal)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .disabled(viewModel.phoneInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Pending Invitations

    private var pendingInvitationsSection: some View {
        Group {
            if !viewModel.pendingInvitations.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Pending Invitations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)

                    ForEach(viewModel.pendingInvitations) { invitation in
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)

                            Text(PhoneNumberNormalizer.formatForDisplay(invitation.invitedPhone))
                                .font(.body)

                            Spacer()

                            Button(role: .destructive) {
                                Task {
                                    await viewModel.revokeInvitation(invitation)
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }
}
