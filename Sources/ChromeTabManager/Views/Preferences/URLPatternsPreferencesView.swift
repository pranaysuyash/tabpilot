import SwiftUI

/// URL Patterns preferences tab — users manage protected/monitored URL wildcard patterns.
struct URLPatternsPreferencesView: View {
    @State private var patterns: [URLPattern] = []
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("URL Patterns")
                        .font(.headline)
                    Text("Define wildcard patterns to match specific URLs and assign actions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Pattern", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            if patterns.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No URL patterns")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(patterns) { pattern in
                        URLPatternRow(
                            pattern: pattern,
                            onToggle: {
                                togglePattern(pattern)
                            },
                            onDelete: {
                                deletePattern(pattern)
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear { patterns = URLPatternStore.shared.loadPatterns() }
        .sheet(isPresented: $showAddSheet) {
            AddPatternSheetView(onSave: {
                patterns = URLPatternStore.shared.loadPatterns()
            })
        }
    }

    private func togglePattern(_ pattern: URLPattern) {
        guard let idx = patterns.firstIndex(where: { $0.id == pattern.id }) else { return }
        patterns[idx].enabled.toggle()
        savePatterns()
    }

    private func deletePattern(_ pattern: URLPattern) {
        patterns.removeAll { $0.id == pattern.id }
        savePatterns()
    }

    private func savePatterns() {
        URLPatternStore.shared.savePatterns(patterns)
    }
}

struct URLPatternRow: View {
    let pattern: URLPattern
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button {
                onToggle()
            } label: {
                Image(systemName: pattern.enabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(pattern.enabled ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.pattern)
                    .font(.subheadline.monospaced())
                HStack(spacing: 4) {
                    if !pattern.description.isEmpty {
                        Text(pattern.description)
                    }
                    Label(pattern.action.rawValue, systemImage: pattern.action.icon)
                        .font(.caption)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(.vertical, 4)
    }
}
