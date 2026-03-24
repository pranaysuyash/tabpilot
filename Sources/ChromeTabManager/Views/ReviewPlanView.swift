import SwiftUI

/// Standalone ReviewPlanView — shows the full review plan as a sheet overlay.
struct ReviewPlanView: View {
    @ObservedObject var viewModel: TabManagerViewModel
    
    var totalToClose: Int {
        viewModel.reviewPlanItems.filter { $0.isIncluded }.reduce(0) { $0 + $1.closeTabs.count }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Cleanup Plan")
                        .font(.title2.bold())
                    Text("\(viewModel.reviewPlanItems.count) groups • Closing \(totalToClose) tabs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        viewModel.cancelReviewPlan()
                    } label: {
                        Text("Cancel")
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button {
                        Task { await viewModel.executeReviewPlan() }
                    } label: {
                        Label("Close \(totalToClose) Tabs", systemImage: "xmark.bin")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(totalToClose == 0)
                    .keyboardShortcut(.defaultAction)
                    .help("Permanently close the selected tabs")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Select / deselect all
            HStack {
                Button("Select All") {
                    for i in viewModel.reviewPlanItems.indices {
                        viewModel.reviewPlanItems[i].isIncluded = true
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Button("Deselect All") {
                    for i in viewModel.reviewPlanItems.indices {
                        viewModel.reviewPlanItems[i].isIncluded = false
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                
                Spacer()
                
                Text("\(totalToClose) tabs will be closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Plan items
            List($viewModel.reviewPlanItems) { $item in
                ReviewPlanItemRow(item: $item)
            }
            .listStyle(.plain)
        }
        .background(Color(.controlBackgroundColor))
        .frame(maxWidth: 880, maxHeight: 700)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Review Plan Item Row

struct ReviewPlanItemRow: View {
    @Binding var item: TabManagerViewModel.ReviewPlanItem
    
    var body: some View {
        HStack(spacing: 16) {
            Toggle("", isOn: $item.isIncluded)
                .toggleStyle(.checkbox)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.group.displayUrl)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(item.keepTab.title.prefix(40), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Text("KEEP")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                
                Text("Closing \(item.closeTabs.count) tabs:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(item.closeTabs) { tab in
                    Label(tab.title.prefix(50), systemImage: "xmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 16)
                }
            }
            
            Spacer()
            
            Text("\(item.closeTabs.count)")
                .font(.title2.bold())
                .foregroundStyle(item.isIncluded ? .red : .secondary)
        }
        .padding(.vertical, 8)
        .opacity(item.isIncluded ? 1.0 : 0.5)
    }
}
