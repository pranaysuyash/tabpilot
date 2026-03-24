import SwiftUI

/// Snapshots tab in Preferences — browse and restore tab snapshots.
struct SnapshotsView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tab Snapshots")
                        .font(.headline)
                    Text("Undo history and manual snapshots of your tab state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Undo snapshot
            if viewModel.canUndo {
                GroupBox("Recent Close (Undo Available)") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(viewModel.undoMessage)
                                .font(.subheadline)
                            Spacer()
                            Button {
                                Task { await viewModel.undoLastClose() }
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        ProgressView(value: viewModel.undoTimeRemaining, total: 30)
                            .tint(viewModel.undoTimeRemaining > 10 ? .blue : .orange)
                        Text("\(Int(viewModel.undoTimeRemaining))s remaining")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No recent undo available")
                        .foregroundStyle(.secondary)
                    Text("After you close tabs, you have 30 seconds to undo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
