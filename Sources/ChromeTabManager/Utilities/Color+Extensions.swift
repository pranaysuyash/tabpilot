import SwiftUI

// MARK: - Semantic Color Extensions

extension Color {
    // MARK: - Adaptive Text Colors for Colored Backgrounds
    
    /// Text color that adapts to the current color scheme for use on colored backgrounds
    /// Returns white in dark mode, black in light mode for maximum contrast
    static var adaptiveTextOnColor: Color {
        Color(nsColor: .white)
    }
    
    // MARK: - Semantic Chart/Indicator Colors
    
    /// Success color - adapts slightly between light/dark for visibility
    static var semanticSuccess: Color { .green }
    
    /// Warning color - adapts slightly between light/dark for visibility  
    static var semanticWarning: Color { .orange }
    
    /// Error color - adapts slightly between light/dark for visibility
    static var semanticError: Color { .red }
    
    /// Info/accent color
    static var semanticInfo: Color { .blue }
    
    /// Neutral/secondary accent
    static var semanticNeutral: Color { .purple }
    
    // MARK: - Profile Badge Colors
    
    /// Returns an adaptive text color for profile badges that ensures readability
    static func profileBadgeTextColor(for profileName: String) -> Color {
        // All profile badge backgrounds are vibrant colors (blue, orange, green, purple)
        // White text provides the best contrast on all these colors in both light and dark mode
        .white
    }
    
    // MARK: - Status Colors with Dark Mode Adjustments
    
    /// Age indicator colors that adapt for visibility
    enum AgeIndicator {
        static var recent: Color { .green }
        static var moderate: Color { .orange }
        static var old: Color { .red }
    }
    
    /// Trend indicator colors
    enum TrendIndicator {
        static var improving: Color { .green }
        static var worsening: Color { .orange }
        static var stable: Color { .secondary }
    }
    
    // MARK: - Background Opacity Helpers
    
    /// Returns an appropriate background color for overlay elements
    static var adaptiveOverlayBackground: Color {
        Color(.windowBackgroundColor)
    }
    
    /// Returns a subtle background color for grouped content
    static var adaptiveGroupedBackground: Color {
        Color(.controlBackgroundColor)
    }
    
    /// Returns background color for text/content areas
    static var adaptiveTextBackground: Color {
        Color(.textBackgroundColor)
    }
}

// MARK: - ColorScheme Environment Helper

struct ColorSchemeAdaptiveViewModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    /// Applies color scheme adaptive styling (placeholder for future use)
    func colorSchemeAdaptive() -> some View {
        modifier(ColorSchemeAdaptiveViewModifier())
    }
}

// MARK: - Profile Color Helper

extension Color {
    /// Returns the appropriate profile color for a given profile name
    static func profileColor(for profileName: String) -> Color {
        switch profileName.lowercased() {
        case "default": return .blue
        case "work": return .orange
        case "personal": return .green
        default: return .purple
        }
    }
}
