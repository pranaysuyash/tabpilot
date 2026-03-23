import SwiftUI

// RECOVERY ADDON: lightweight flow layout for wrapping chips/tags.
struct FlowLayoutRecovery: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                maxLineWidth = max(maxLineWidth, lineWidth)
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + (lineWidth > 0 ? spacing : 0)
                lineHeight = max(lineHeight, size.height)
            }
        }

        totalHeight += lineHeight
        maxLineWidth = max(maxLineWidth, lineWidth)
        return CGSize(width: maxLineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }

            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
