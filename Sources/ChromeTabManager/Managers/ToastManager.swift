import SwiftUI
import Combine

/// Manages toast notifications throughout the app
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastItem?
    
    struct ToastItem: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let type: ToastType
        let duration: TimeInterval
        
        static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
            lhs.id == rhs.id && lhs.message == rhs.message && lhs.type == rhs.type
        }
        
        enum ToastType: Equatable {
            case success
            case info
            case warning
            case error
            
            var color: Color {
                switch self {
                case .success: return .green
                case .info: return .blue
                case .warning: return .orange
                case .error: return .red
                }
            }
            
            var icon: String {
                switch self {
                case .success: return "checkmark.circle.fill"
                case .info: return "info.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.circle.fill"
                }
            }
        }
    }
    
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    func show(message: String, type: ToastItem.ToastType = .info, duration: TimeInterval = 4.0) {
        dismissTask?.cancel()
        
        currentToast = ToastItem(
            message: message,
            type: type,
            duration: duration
        )
        
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                dismiss()
            }
        }
    }
    
    func showSuccess(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .success, duration: duration)
    }
    
    func showInfo(_ message: String, duration: TimeInterval = 4.0) {
        show(message: message, type: .info, duration: duration)
    }
    
    func showWarning(_ message: String, duration: TimeInterval = 5.0) {
        show(message: message, type: .warning, duration: duration)
    }
    
    func showError(_ message: String, duration: TimeInterval = 6.0) {
        show(message: message, type: .error, duration: duration)
    }
    
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        currentToast = nil
    }
}

// MARK: - Toast Overlay View

struct ToastOverlay: ViewModifier {
    @StateObject private var manager = ToastManager.shared
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            // Toast overlay
            VStack {
                Spacer()
                
                if let toast = manager.currentToast {
                    ToastBanner(item: toast)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.currentToast)
        }
    }
}

struct ToastBanner: View {
    let item: ToastManager.ToastItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.icon)
                .foregroundStyle(item.type.color)
                .font(.title3)
            
            Text(item.message)
                .font(.subheadline)
                .lineLimit(2)
            
            Spacer()
            
            Button {
                ToastManager.shared.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
