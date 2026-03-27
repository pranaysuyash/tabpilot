import SwiftUI

/// Represents a single data point for sparkline
struct SparklineDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String
}

/// A reusable mini sparkline view for displaying time-series data
struct SparklineView: View {
    let data: [SparklineDataPoint]
    let height: CGFloat
    let showDots: Bool
    let lineWidth: CGFloat
    
    @State private var hoveredPoint: SparklineDataPoint?
    @State private var isHovered = false
    
    init(
        data: [SparklineDataPoint],
        height: CGFloat = 30,
        showDots: Bool = true,
        lineWidth: CGFloat = 1.5
    ) {
        self.data = data.sorted { $0.date < $1.date }
        self.height = height
        self.showDots = showDots
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Line chart
                linePath(in: geometry.size)
                    .stroke(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: lineWidth
                    )
                
                // Dots for each data point
                if showDots {
                    ForEach(data) { point in
                        Circle()
                            .fill(dotColor(for: point))
                            .frame(width: 4, height: 4)
                            .position(
                                x: xPosition(for: point, in: geometry.size.width),
                                y: yPosition(for: point.value, in: geometry.size.height)
                            )
                            .opacity(hoveredPoint?.id == point.id ? 1.0 : 0.7)
                            .scaleEffect(hoveredPoint?.id == point.id ? 1.3 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: hoveredPoint?.id)
                    }
                }
                
                // Hover detection overlay
                if !data.isEmpty {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                isHovered = true
                                hoveredPoint = findNearestPoint(to: location.x, in: geometry.size.width)
                            case .ended:
                                isHovered = false
                                hoveredPoint = nil
                            }
                        }
                }
                
                // Tooltip
                if let point = hoveredPoint {
                    tooltipView(for: point)
                        .position(
                            x: min(max(xPosition(for: point, in: geometry.size.width), 60),
                                   geometry.size.width - 60),
                            y: yPosition(for: point.value, in: geometry.size.height) - 25
                        )
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
        }
        .frame(height: height)
    }
    
    // MARK: - Computed Properties
    
    private var maxValue: Double {
        data.map(\.value).max() ?? 0
    }
    
    private var minValue: Double {
        data.map(\.value).min() ?? 0
    }
    
    private var valueRange: Double {
        let range = maxValue - minValue
        return range == 0 ? 1 : range // Avoid division by zero
    }
    
    private var isTrendingUp: Bool {
        guard data.count >= 2 else { return false }
        let sorted = data.sorted { $0.date < $1.date }
        let first = sorted.first!.value
        let last = sorted.last!.value
        return last > first
    }
    
    private var gradientColors: [Color] {
        if isTrendingUp {
            return [.green.opacity(0.6), .green]
        } else {
            return [.orange.opacity(0.6), .red]
        }
    }
    
    // MARK: - Path Drawing
    
    private func linePath(in size: CGSize) -> Path {
        guard data.count >= 2 else { return Path() }
        
        var path = Path()
        let sortedData = data.sorted { $0.date < $1.date }
        
        // Move to first point
        let firstPoint = sortedData[0]
        let startX = xPosition(for: firstPoint, in: size.width)
        let startY = yPosition(for: firstPoint.value, in: size.height)
        path.move(to: CGPoint(x: startX, y: startY))
        
        // Draw line to each subsequent point using smooth curves
        for i in 1..<sortedData.count {
            let point = sortedData[i]
            let x = xPosition(for: point, in: size.width)
            let y = yPosition(for: point.value, in: size.height)
            
            if i == 1 {
                // Straight line to second point
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                // Use quadratic curve for smooth transitions
                let prevPoint = sortedData[i - 1]
                let prevX = xPosition(for: prevPoint, in: size.width)
                let prevY = yPosition(for: prevPoint.value, in: size.height)
                
                let controlX = (prevX + x) / 2
                path.addQuadCurve(
                    to: CGPoint(x: x, y: y),
                    control: CGPoint(x: controlX, y: (prevY + y) / 2)
                )
            }
        }
        
        return path
    }
    
    // MARK: - Position Calculations
    
    private func xPosition(for point: SparklineDataPoint, in width: CGFloat) -> CGFloat {
        guard data.count > 1 else { return width / 2 }
        let sorted = data.sorted { $0.date < $1.date }
        guard let index = sorted.firstIndex(where: { $0.id == point.id }) else { return 0 }
        let step = width / CGFloat(sorted.count - 1)
        return CGFloat(index) * step
    }
    
    private func yPosition(for value: Double, in height: CGFloat) -> CGFloat {
        let normalized = (value - minValue) / valueRange
        // Invert because SwiftUI y=0 is at top
        return height - (normalized * height * 0.8 + height * 0.1)
    }
    
    private func findNearestPoint(to x: CGFloat, in width: CGFloat) -> SparklineDataPoint? {
        guard !data.isEmpty else { return nil }
        let sorted = data.sorted { $0.date < $1.date }
        let step = width / CGFloat(max(sorted.count - 1, 1))
        let index = min(Int(round(x / step)), sorted.count - 1)
        return sorted[max(0, index)]
    }
    
    // MARK: - Dot Color
    
    private func dotColor(for point: SparklineDataPoint) -> Color {
        guard let index = data.sorted(by: { $0.date < $1.date }).firstIndex(where: { $0.id == point.id }),
              index > 0 else {
            return .secondary
        }
        
        let sorted = data.sorted { $0.date < $1.date }
        let prevValue = sorted[index - 1].value
        
        if point.value > prevValue {
            return .green
        } else if point.value < prevValue {
            return .orange
        } else {
            return .secondary
        }
    }
    
    // MARK: - Tooltip
    
    private func tooltipView(for point: SparklineDataPoint) -> some View {
        VStack(spacing: 2) {
            Text(point.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatDuration(point.value))
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.primary.opacity(0.15), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let totalHours = totalMinutes / 60
        
        if totalHours >= 1 {
            let minutes = totalMinutes % 60
            if minutes > 0 {
                return "\(totalHours)h \(minutes)m"
            } else {
                return "\(totalHours)h"
            }
        } else if totalMinutes >= 1 {
            return "\(totalMinutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Example with increasing trend
        SparklineView(
            data: [
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 6), value: 300, label: "6 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 5), value: 450, label: "5 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 4), value: 400, label: "4 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 3), value: 600, label: "3 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 2), value: 800, label: "2 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 1), value: 750, label: "Yesterday"),
                SparklineDataPoint(date: Date(), value: 1200, label: "Today")
            ],
            height: 30
        )
        .frame(width: 150)
        
        // Example with decreasing trend
        SparklineView(
            data: [
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 6), value: 1200, label: "6 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 5), value: 1000, label: "5 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 4), value: 1100, label: "4 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 3), value: 800, label: "3 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 2), value: 600, label: "2 days ago"),
                SparklineDataPoint(date: Date().addingTimeInterval(-86400 * 1), value: 400, label: "Yesterday"),
                SparklineDataPoint(date: Date(), value: 300, label: "Today")
            ],
            height: 30
        )
        .frame(width: 150)
        
        // Example with no data
        SparklineView(data: [], height: 30)
            .frame(width: 150)
    }
    .padding()
}
