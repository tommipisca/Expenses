import SwiftUI
import ExpensesCore

/// Anello diviso per tag, con spazi tra le fette ed estremi arrotondati.
struct RingChart: View {
    let slices: [TagSlice]
    var lineWidthRatio: CGFloat = 22.0 / 200
    var gapDegrees: Double = 4
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let lineWidth = diameter * lineWidthRatio
            let circumference = Double.pi * Double(diameter - lineWidth)
            // Ogni estremo arrotondato sporge di metà spessore: si accorcia la fetta di altrettanto.
            let inset = Double(lineWidth / 2) / circumference + gapDegrees / 720
            ZStack {
                Circle().stroke(Theme.surface, lineWidth: lineWidth)
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let from = segment.start + (slices.count > 1 ? inset : 0)
                    let to = max(from, segment.end - (slices.count > 1 ? inset : 0))
                    Circle()
                        .trim(from: from * progress, to: to * progress)
                        .stroke(Theme.tagColor(index: segment.colorIndex),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: slices.count > 1 ? .round : .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            .padding(lineWidth / 2)
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { progress = 1 } }
        .accessibilityElement()
        .accessibilityLabel(slices.map { "\($0.name) \(Formatting.percent($0.fraction))" }.joined(separator: ", "))
    }

    private var segments: [(start: Double, end: Double, colorIndex: Int?)] {
        var start = 0.0
        return slices.map { slice in
            defer { start += slice.fraction }
            return (start, start + slice.fraction, slice.colorIndex)
        }
    }
}
