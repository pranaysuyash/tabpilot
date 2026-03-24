import SwiftUI
import AppKit

// MARK: - WCAG Color Semantics

extension Color {
    /// Primary text color intended for standard contrast targets (WCAG AA 4.5:1 on supported backgrounds).
    static let primaryText = Color.primary

    /// Secondary text color intended for supporting labels/content (WCAG AA 3:1 for large/supporting text contexts).
    static let secondaryText = Color.secondary

    /// Accent color for interactive UI elements.
    static let interactiveAccent = Color.accentColor

    /// Relative luminance in sRGB color space, used for WCAG contrast calculations.
    var luminance: Double {
        let resolved = NSColor(self).usingColorSpace(.sRGB) ?? .black

        func linearize(_ component: CGFloat) -> Double {
            let c = Double(component)
            if c <= 0.03928 {
                return c / 12.92
            }
            return pow((c + 0.055) / 1.055, 2.4)
        }

        let r = linearize(resolved.redComponent)
        let g = linearize(resolved.greenComponent)
        let b = linearize(resolved.blueComponent)

        return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    }
}

/// Returns WCAG contrast ratio between two colors.
func contrastRatio(between color1: Color, and color2: Color) -> Double {
    let luminance1 = color1.luminance
    let luminance2 = color2.luminance

    let lighter = max(luminance1, luminance2)
    let darker = min(luminance1, luminance2)

    return (lighter + 0.05) / (darker + 0.05)
}

enum WCAGContrastLevel {
    case normalAA
    case largeTextAA
}

func passesWCAGContrast(_ ratio: Double, level: WCAGContrastLevel) -> Bool {
    switch level {
    case .normalAA:
        return ratio >= 4.5
    case .largeTextAA:
        return ratio >= 3.0
    }
}

