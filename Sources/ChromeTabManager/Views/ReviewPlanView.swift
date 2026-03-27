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
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("\(viewModel.reviewPlanItems.count) groups • Closing \(totalToClose) tabs")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(viewModel.reviewPlanItems.count) groups, closing \(totalToClose) tabs")
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        viewModel.cancelReviewPlan()
                    } label: {
                        Text("Cancel")
                    }
                    .keyboardShortcut(.cancelAction)
                    .accessibleLabel("Cancel", hint: "Closes the review plan without making changes")
                    
                    Button {
                        Task { await viewModel.executeReviewPlan() }
                    } label: {
                        Label("Close \(totalToClose) Tabs", systemImage: "xmark.bin")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(totalToClose == 0)
                    .keyboardShortcut(.defaultAction)
                    .accessibleLabel("Close \(totalToClose) tabs", hint: "Permanently closes the selected tabs. This cannot be undone.")
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
                    AccessibilityAnnouncements.announce("All items selected")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .accessibleLabel("Select all", hint: "Selects all groups in the cleanup plan")
                
                Button("Deselect All") {
                    for i in viewModel.reviewPlanItems.indices {
                        viewModel.reviewPlanItems[i].isIncluded = false
                    }
                    AccessibilityAnnouncements.announce("All items deselected")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .accessibleLabel("Deselect all", hint: "Deselects all groups in the cleanup plan")
                
                Spacer()
                
                Text("\(totalToClose) tabs will be closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(totalToClose) tabs will be closed")
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.adaptiveGroupedBackground)
            
            Divider()
            
            // Plan items
            List($viewModel.reviewPlanItems) { $item in
                ReviewPlanItemRow(item: $item)
            }
            .listStyle(.plain)
            .accessibilityLabel("Cleanup plan items list")
        }
        .background(Color.adaptiveGroupedBackground)
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
                .accessibilityLabel("Include \(item.group.displayUrl)")
                .accessibilityHint("Toggle whether to include this group in the cleanup")
                .accessibilityValue(item.isIncluded ? "included" : "excluded")
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.group.displayUrl)
                    .font(.subheadline)
                    .lineLimit(1)
                    .accessibilityLabel("URL: \(item.group.displayUrl)")
                
                HStack(spacing: 8) {
                    Label(item.keepTab.title.prefix(40), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    
                    Text("KEEP")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Keep: \(item.keepTab.title)")
                
                Text("Closing \(item.closeTabs.count) tabs:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Closing \(item.closeTabs.count) tabs")
                
                ForEach(item.closeTabs) { tab in
                    Label(tab.title.prefix(50), systemImage: "xmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 16)
                        .accessibilityLabel("Close: \(tab.title)")
                }
            }
            
            Spacer()
            
            Text("\(item.closeTabs.count)")
                .font(.title2.bold())
                .foregroundStyle(item.isIncluded ? .red : .secondary)
                .accessibilityLabel("\(item.closeTabs.count) tabs to close")
        }
        .padding(.vertical, 8)
        .opacity(item.isIncluded ? 1.0 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.group.displayUrl), keeping \(item.keepTab.title), closing \(item.closeTabs.count) tabs")
        .accessibilityValue(item.isIncluded ? "included in cleanup" : "excluded from cleanup")
        .accessibilityHint("Toggle checkbox to include or exclude this group")
    }
}
