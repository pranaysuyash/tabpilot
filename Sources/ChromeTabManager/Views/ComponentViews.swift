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
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatBadge: View {
    let value: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            
            HStack(spacing: 4) {
                if isOldest {
                    Image(systemName: "1.circle.fill")
                        .foregroundStyle(.green)
                    Text("FIRST")
                        .foregroundStyle(.green)
                } else if isNewest {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(.blue)
                    Text("LAST")
                        .foregroundStyle(.blue)
                }
            }
            .font(.caption.bold())
            .frame(width: 80, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("Window \(tab.windowId) • Tab \(tab.tabIndex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if showAge {
                Text(tab.ageDescription)
                    .font(.caption)
                    .foregroundStyle(ageColor)
            }
            
            Button {
                Task { await onFocus() }
            } label: {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Focus tab in Chrome")
        }
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    var ageColor: Color {
        let seconds = Date().timeIntervalSince(tab.openedAt)
        if seconds >= 86400 { return .red }
        if seconds >= 3600 { return .orange }
        return .green
    }
}
