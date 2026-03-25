//
//  MessageComposeView.swift
//  loc
//
//  UIViewControllerRepresentable wrapping MFMessageComposeViewController
//

import SwiftUI
import MessageUI

/// SwiftUI wrapper for the native SMS compose screen.
struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onResult: (MessageComposeResult) -> Void

    /// Returns whether the device can send text messages.
    static var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onResult: (MessageComposeResult) -> Void

        init(onResult: @escaping (MessageComposeResult) -> Void) {
            self.onResult = onResult
        }

        /// Handles the result of the message compose view controller.
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            onResult(result)
            controller.dismiss(animated: true)
        }
    }
}
