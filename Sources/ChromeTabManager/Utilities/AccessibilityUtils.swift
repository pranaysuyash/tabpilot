import SwiftUI
import Accessibility

// MARK: - VoiceOver Labels

/// Provides comprehensive accessibility labels for common UI elements
struct AccessibleLabelModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits?
    
    init(label: String, hint: String? = nil, traits: AccessibilityTraits? = nil) {
        self.label = label
        self.hint = hint
        self.traits = traits
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits ?? .isButton)
    }
}

extension View {
    /// Adds comprehensive accessibility label with hint and optional traits
    func accessibleLabel(_ label: String, hint: String? = nil, traits: AccessibilityTraits? = nil) -> some View {
        modifier(AccessibleLabelModifier(label: label, hint: hint, traits: traits))
    }
    
    /// Groups children for VoiceOver as a single element
    func accessibilityGrouped(_ label: String, hint: String? = nil) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    /// Makes view a single accessibility element with custom label
    func accessibilitySingleElement(_ label: String, hint: String? = nil) -> some View {
        self.accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Announcements

/// Accessibility announcement helpers
@MainActor
enum AccessibilityAnnouncements {
    /// Announces a message to VoiceOver users
    static func announce(_ message: String) {
        AccessibilityNotification.announcement.post(argument: message)
    }
    
    /// Announces scan completion
    static func scanComplete(tabs: Int, duplicates: Int) {
        announce("Scan complete. Found \(tabs) tabs, \(duplicates) duplicate groups.")
    }
    
    /// Announces selection changes
    static func selectionChanged(count: Int, total: Int) {
        announce("Selected \(count) of \(total) items")
    }
    
    /// Announces tab closure
    static func tabsClosed(count: Int) {
        announce("Closed \(count) tabs")
    }
    
    /// Announces undo action
    static func undoRestored(count: Int) {
        announce("Restored \(count) tabs")
    }
}

// MARK: - Scalable Font Modifier

struct ScalableFont: ViewModifier {
    let textStyle: Font.TextStyle
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content
            .font(.system(textStyle, design: .default))
    }
}

extension View {
    func scalableFont(_ textStyle: Font.TextStyle) -> some View {
        modifier(ScalableFont(textStyle: textStyle))
    }
}

// MARK: - Dynamic Type Size Limits

struct DynamicTypeSizeLimit: ViewModifier {
    let maximumSize: DynamicTypeSize
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...maximumSize)
    }
}

extension View {
    func dynamicTypeSizeLimit(_ maximumSize: DynamicTypeSize) -> some View {
        modifier(DynamicTypeSizeLimit(maximumSize: maximumSize))
    }
}

// MARK: - Reduce Motion Support

struct ReduceMotionToggle: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    let animation: Animation?
    let reducedAnimation: Animation?
    
    init(animation: Animation? = .default, reducedAnimation: Animation? = nil) {
        self.animation = animation
        self.reducedAnimation = reducedAnimation
    }
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : animation, value: reduceMotion)
    }
}

extension View {
    func reduceMotionToggle(animation: Animation? = .default, reducedAnimation: Animation? = nil) -> some View {
        modifier(ReduceMotionToggle(animation: animation, reducedAnimation: reducedAnimation))
    }
}

// MARK: - High Contrast Support

struct HighContrastAdaptive: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .foregroundStyle(contrast == .increased ? Color.primary : Color.primary)
            .background(contrast == .increased ? Color(NSColor.textBackgroundColor) : Color.clear)
    }
}

extension View {
    func highContrastAdaptive() -> some View {
        modifier(HighContrastAdaptive())
    }
}

// MARK: - Focus Management

/// Focus management for form fields
enum AccessibleFocusField: Hashable {
    case search
    case filter
    case patternInput
    case fileName
    case primaryButton
    case secondaryButton
    case tabList
    case sidebar
    case mainContent
}

/// Focus state management helper
@MainActor
class AccessibilityFocusManager: ObservableObject {
    @Published var focusedField: AccessibleFocusField?
    
    func moveFocus(to field: AccessibleFocusField) {
        focusedField = field
    }
    
    func clearFocus() {
        focusedField = nil
    }
}

// MARK: - Toggle Accessibility

extension Toggle {
    /// Makes toggle fully accessible with value
    func accessibleToggle(_ label: String, hint: String? = nil, isOn: Bool) -> some View {
        self.accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(isOn ? "on" : "off")
            .accessibilityAddTraits(.isButton)
    }
}
