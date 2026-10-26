//
//  WaitingListView.swift
//  loc
//
//  Shown to signed-in users who aren't approved yet. No buttons needed: it re-checks
//  every 20s and whenever the app comes to the foreground, and unlocks by itself.
//

import SwiftUI

struct WaitingListView: View {
    @EnvironmentObject var userSession: UserSession
    private let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    private var isRejected: Bool { userSession.approvalStatus == .rejected }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: isRejected ? "hand.raised" : "sparkles")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.black)
                Text(isRejected ? "Mesa is invite-only for now" : "You're on the list")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
                Text(isRejected
                     ? "We can't let you in just yet. We'll reach out if that changes."
                     : "Mesa is invite-only while we grow. We'll open the doors for you shortly. This screen unlocks on its own.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                if !isRejected {
                    ProgressView().padding(.top, 6)
                }
                Spacer()
                Button("Log out") { userSession.logout() }
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .padding(.bottom, 24)
            }
        }
        .onAppear { Analytics.track(.waitlistShown, ["status": userSession.approvalStatus.rawValue]) }
        .onReceive(timer) { _ in Task { await userSession.refreshApprovalStatus() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await userSession.refreshApprovalStatus() }
        }
    }
}
