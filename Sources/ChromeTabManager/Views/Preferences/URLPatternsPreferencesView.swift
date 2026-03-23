import SwiftUI

/// URL Patterns preferences tab — users manage protected/monitored URL wildcard patterns.
struct URLPatternsPreferencesView: View {
    @State private var patterns: [URLPattern] = []
    @State private var showAddSheet = false
    @State private var newPattern = ""
    @State private var newDescription = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("URL Patterns")
                        .font(.headline)
                    Text("Define wildcard patterns to match specific URLs.")
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
                        URLPatternRow(pattern: pattern, onDelete: {
                            patterns.removeAll { $0.id == pattern.id }
                            savePatterns()
                        })
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear { patterns = URLPatternStore.shared.loadPatterns() }
    }
    
    private func savePatterns() {
        URLPatternStore.shared.savePatterns(patterns)
    }
}

struct URLPatternRow: View {
    let pattern: URLPattern
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.pattern)
                    .font(.subheadline.monospaced())
                if !pattern.description.isEmpty {
                    Text(pattern.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
