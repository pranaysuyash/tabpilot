import SwiftUI

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

// MARK: - VoiceOver Support

struct AccessibleLabel: ViewModifier {
    let label: String
    let hint: String?
    
    init(label: String, hint: String? = nil) {
        self.label = label
        self.hint = hint
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map { Text($0) } ?? Text(""))
    }
}

extension View {
    func accessibleLabel(_ label: String, hint: String? = nil) -> some View {
        modifier(AccessibleLabel(label: label, hint: hint))
    }
}

// MARK: - Keyboard Navigation

struct KeyboardFocusable: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .focusable()
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
