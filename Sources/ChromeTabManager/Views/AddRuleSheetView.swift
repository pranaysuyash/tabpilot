import SwiftUI

struct AddRuleSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: (() -> Void)? = nil

    @State private var patternText = ""
    @State private var patternDescription = ""
    @State private var isEnabled = true
    @State private var maxAgeDays: Int = 0
    @State private var previewTabs: [TabInfo] = []
    @State private var isLoadingPreview = false
    @State private var excludedTabIds: Set<String> = []
    @State private var allTabs: [TabInfo] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Cleanup Rule")
                .font(.headline)

            Form {
                TextField("URL Pattern", text: $patternText)
                    .onChange(of: patternText) { _, _ in
                        updatePreview()
                    }

                TextField("Description (optional)", text: $patternDescription)

                HStack {
                    Text("Max Age (days)")
                    Spacer()
                    TextField("0", value: $maxAgeDays, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: maxAgeDays) { _, newValue in
                            if newValue < 0 { maxAgeDays = 0 }
                        }
                }

                Toggle("Enabled", isOn: $isEnabled)
            }

            previewSection

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Rule") {
                    addRule()
                    dismiss()
                    onSave?()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(patternText.isEmpty)
            }
        }
        .padding()
        .frame(width: 450, height: 420)
        .task {
            await loadTabs()
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    Task { await loadTabs() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(isLoadingPreview)
            }

            if isLoadingPreview {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning tabs...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if previewTabs.isEmpty {
                if patternText.isEmpty {
                    Text("Enter a pattern to see matching tabs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    Text("No matching tabs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            } else {
                let visibleTabs = previewTabs.filter { !excludedTabIds.contains($0.id) }
                HStack {
                    Text("\(visibleTabs.count) tab\(visibleTabs.count == 1 ? "" : "s") will be affected")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !excludedTabIds.isEmpty {
                        Button("Reset Exclusions") {
                            excludedTabIds.removeAll()
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(visibleTabs) { tab in
                            domainChip(for: tab)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func domainChip(for tab: TabInfo) -> some View {
        HStack(spacing: 4) {
            Text(tab.domain)
                .font(.caption)
                .lineLimit(1)

            Button {
                excludedTabIds.insert(tab.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.15))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }

    private func loadTabs() async {
        isLoadingPreview = true
        do {
            let result = try await ChromeController.shared.scanAllTabsFast { _, _ in }
            allTabs = result.tabs
            updatePreview()
        } catch {
            SecureLogger.error("Failed to load tabs for preview: \(error.localizedDescription)")
            allTabs = []
            previewTabs = []
        }
        isLoadingPreview = false
    }

    private func updatePreview() {
        guard !patternText.isEmpty else {
            previewTabs = []
            return
        }

        let pattern = URLPattern(
            pattern: patternText,
            enabled: true,
            description: patternDescription.isEmpty ? patternText : patternDescription
        )

        let rule = CleanupRule(
            name: patternDescription.isEmpty ? patternText : patternDescription,
            pattern: pattern,
            action: .close,
            enabled: true,
            maxAgeDays: maxAgeDays > 0 ? maxAgeDays : nil
        )

        previewTabs = AutoCleanupManager.shared.previewRule(rule, against: allTabs)
    }

    private func addRule() {
        let pattern = URLPattern(
            pattern: patternText,
            enabled: isEnabled,
            description: patternDescription.isEmpty ? patternText : patternDescription
        )

        let rule = CleanupRule(
            name: patternDescription.isEmpty ? patternText : patternDescription,
            pattern: pattern,
            action: .close,
            enabled: isEnabled,
            maxAgeDays: maxAgeDays > 0 ? maxAgeDays : nil
        )

        CleanupRuleStore.shared.add(rule)
    }
}
