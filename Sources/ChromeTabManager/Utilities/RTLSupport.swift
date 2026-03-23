import SwiftUI

// MARK: - RTL Language Support

/// Returns the appropriate leading/trailing direction based on layout direction
struct DirectionalLayout {
    static var leading: HorizontalEdge { .leading }
    static var trailing: HorizontalEdge { .trailing }
    
    static var leadingPadding: Edge.Set { .leading }
    static var trailingPadding: Edge.Set { .trailing }
    
    static var minimumSpaceIndex: Int { 0 }
    static var maximumSpaceIndex: Int { 1 }
}

// MARK: - Directional Spacer

/// A spacer that adapts to RTL layout direction
struct DirectionalSpacer: View {
    var length: CGFloat? = nil
    
    var body: some View {
        if let length = length {
            Spacer()
                .frame(width: length)
        } else {
            Spacer()
        }
    }
}

// MARK: - Directional Image

/// Image that flips on RTL (for directional icons like arrows)
struct DirectionalImage: View {
    let systemName: String
    let rtlFlipped: Bool
    
    @Environment(\.layoutDirection) var layoutDirection
    
    init(_ systemName: String, rtlFlipped: Bool = true) {
        self.systemName = systemName
        self.rtlFlipped = rtlFlipped
    }
    
    var body: some View {
        if rtlFlipped && layoutDirection == .rightToLeft {
            Image(systemName: systemName)
                .rotationEffect(.degrees(180))
        } else {
            Image(systemName: systemName)
        }
    }
}

// MARK: - Directional HStack

/// HStack that reverses on RTL
struct DirectionalHStack<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.layoutDirection) var layoutDirection
    
    var body: some View {
        HStack(spacing: 0) {
            content()
        }
        .flipsForRightToLeftLayoutDirection(layoutDirection == .rightToLeft)
    }
}

// MARK: - Force RTL Modifier (for testing)

struct ForceLayoutDirection: ViewModifier {
    let direction: LayoutDirection
    
    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, direction)
    }
}

extension View {
    func forceLayoutDirection(_ direction: LayoutDirection) -> some View {
        modifier(ForceLayoutDirection(direction: direction))
    }
}

// MARK: - RTLAwareView

/// Example reusable row that respects layout direction and flips directional iconography for RTL locales.
struct RTLAwareView: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let text: LocalizedStringKey

    init(text: LocalizedStringKey = "Content") {
        self.text = text
    }

    var body: some View {
        HStack {
            Image(systemName: "arrow.right")
                .rotationEffect(layoutDirection == .rightToLeft ? .degrees(180) : .zero)

            Text(text)

            Spacer()
        }
        .padding(.leading)
    }
}

/// A proportional spacer that can be used where direction-aware layouts need percentage spacing.
struct ProportionalDirectionalSpacer: View {
    let fraction: CGFloat

    init(fraction: CGFloat = 0.1) {
        self.fraction = min(max(fraction, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .frame(width: geometry.size.width * fraction)
        }
        .frame(height: 0)
    }
}
