import SwiftUI

// MARK: - Core Reusable Views

struct ToastView: View {
    let message: String?
    let isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            if isShowing, let message = message {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .accessibilityHidden(true)
                    
                    Text(message)
                        .font(.subheadline)
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(message)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityHint("Toast notification")
            }
        }
    }
}

struct BigStat: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibleLabel(title, hint: "Selects tabs in this group based on '\(title)' strategy")
    }
}

struct TabRow: View {
    let tab: TabInfo
    let isOldest: Bool
    let isNewest: Bool
    let isSelected: Bool
    let showAge: Bool
    let onToggle: () -> Void
    let onFocus: () async -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: .init(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .accessibilityLabel("Select \(tab.title)")
            .accessibilityHint("Marks this tab for bulk close action")
            .accessibilityValue(isSelected ? "selected" : "not selected")
            
            HStack(spacing: 4) {
                if isOldest {
                    Image(systemName: "1.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    
                    Text("FIRST")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                } else if isNewest {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    
                    Text("LAST")
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                }
            }
            .font(.caption.bold())
            .frame(width: 80, alignment: .leading)
            .accessibilityLabel(isOldest ? "First seen tab" : isNewest ? "Last seen tab" : "")
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .accessibilityLabel("Title: \(tab.title)")
                
                Text("Window \(tab.windowId) • Tab \(tab.tabIndex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Window \(tab.windowId), Tab \(tab.tabIndex)")
            }
            
            Spacer()
            
            if showAge {
                Text(tab.ageDescription)
                    .font(.caption)
                    .foregroundStyle(ageColor)
                    .accessibilityLabel("Opened \(tab.ageDescription) ago")
            }
            
            Button {
                Task { await onFocus() }
            } label: {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Focus tab in Chrome")
            .accessibleLabel("Focus tab in Chrome", hint: "Switches to this tab in Chrome")
        }
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tab.title), Window \(tab.windowId), Tab \(tab.tabIndex)\(isOldest ? ", first seen" : isNewest ? ", last seen" : "")")
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityHint("Double-tap to toggle selection")
    }
    
    var ageColor: Color {
        let seconds = Date().timeIntervalSince(tab.openedAt)
        if seconds >= 86400 { return .red }
        if seconds >= 3600 { return .orange }
        return .green
    }
}
