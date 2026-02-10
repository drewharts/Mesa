//
//  GoogleMapsImportView.swift
//  loc
//
//  Created by Claude on 2/9/26.
//
//  SMART View: Main container for the Google Maps list import flow.
//  Single Responsibility: Routes between import phases and presents phase-specific UI.
//

import SwiftUI
import WebKit

/// Full-screen sheet that guides users through importing places from a Google Maps list.
struct GoogleMapsImportView: View {
    @StateObject private var viewModel = GoogleMapsImportViewModel()
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                switch viewModel.importPhase {
                case .input:
                    inputPhase
                case .extracting:
                    extractingPhase
                case .resolving:
                    resolvingPhase
                case .review:
                    GoogleMapsImportReviewView(viewModel: viewModel)
                case .importing:
                    importingPhase
                case .complete:
                    completePhase
                }
            }
            .navigationTitle("Import from Google Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.importPhase == .input || viewModel.importPhase == .complete {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Input Phase

    private var inputPhase: some View {
        ScrollView {
            VStack(spacing: 24) {
                instructionsSection
                urlInputSection

                if let error = viewModel.errorMessage {
                    ImportErrorBanner(message: error)
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private var instructionsSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Import Places from a Google Maps List")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Open a Google Maps list, tap Share, and paste the link below to import all places.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var urlInputSection: some View {
        VStack(spacing: 12) {
            TextField("Paste Google Maps list link...", text: $viewModel.urlText)
                .textFieldStyle(.roundedBorder)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            Button {
                Task { await viewModel.processURL() }
            } label: {
                Text("Import Places")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.canProcess ? Color.blue : Color.gray)
                    )
            }
            .disabled(!viewModel.canProcess)
        }
    }

    // MARK: - Extracting Phase (Shows WebView for debugging)

    private var extractingPhase: some View {
        VStack(spacing: 0) {
            // Show the actual WebView so we can see what Google Maps is rendering
            if let webView = viewModel.extractor.webView {
                ExtractorWebViewRepresentable(webView: webView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            }

            // Status bar at the bottom
            ExtractorStatusBar(statusText: viewModel.extractor.statusText)
        }
    }

    // MARK: - Resolving Phase

    private var resolvingPhase: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView(
                value: Double(viewModel.reviewViewModel.resolutionProgress),
                total: Double(max(1, viewModel.reviewViewModel.totalToResolve))
            )
            .progressViewStyle(LinearProgressViewStyle())
            .padding(.horizontal, 40)

            Text("Finding places... \(viewModel.reviewViewModel.resolutionProgress) of \(viewModel.reviewViewModel.totalToResolve)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Importing Phase

    private var importingPhase: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView(
                value: Double(viewModel.reviewViewModel.importProgress),
                total: Double(max(1, viewModel.reviewViewModel.importTotal))
            )
            .progressViewStyle(LinearProgressViewStyle())
            .padding(.horizontal, 40)

            Text("Importing... \(viewModel.reviewViewModel.importProgress) of \(viewModel.reviewViewModel.importTotal)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Complete Phase

    private var completePhase: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("Import Complete")
                .font(.title2)
                .fontWeight(.bold)

            if let summary = viewModel.reviewViewModel.importSummary {
                ImportSummaryView(summary: summary, listName: viewModel.selectedListName)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

}

// MARK: - Dumb Components

/// Bridges a WKWebView instance into SwiftUI for display.
private struct ExtractorWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Displays the current extraction status at the bottom of the screen.
private struct ExtractorStatusBar: View {
    let statusText: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
    }
}

/// Displays an error message banner with an icon.
private struct ImportErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }
}

/// Displays the import summary with counts of imported, failed, and skipped places.
private struct ImportSummaryView: View {
    let summary: ImportSummary
    let listName: String?

    var body: some View {
        VStack(spacing: 4) {
            if summary.imported > 0 {
                Text("\(summary.imported) places added\(listName.map { " to \($0)" } ?? "")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if summary.failed > 0 {
                Text("\(summary.failed) failed to import")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
            if summary.skipped > 0 {
                Text("\(summary.skipped) skipped")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
