import MopCore
import SwiftUI

/// Ring showing used space, with the purgeable part highlighted.
struct DiskUsageRing: View {
    let disk: DiskInfo
    var lineWidth: CGFloat = 14

    private var usedColor: Color {
        switch disk.usedFraction {
        case 0.9...: .red
        case 0.75...: .orange
        default: .accentColor
        }
    }

    var body: some View {
        let used = disk.usedFraction
        let purgeableStart = max(0, used - disk.purgeableFraction)
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: purgeableStart)
                .stroke(usedColor.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if disk.purgeable > 0 {
                Circle()
                    .trim(from: purgeableStart, to: used)
                    .stroke(usedColor.opacity(0.35), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text(used, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: lineWidth * 1.9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("used")
                    .font(.system(size: max(10, lineWidth * 0.95)))
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.smooth, value: used)
        .accessibilityElement()
        .accessibilityLabel("Disk \(Int(used * 100)) percent used")
    }
}
