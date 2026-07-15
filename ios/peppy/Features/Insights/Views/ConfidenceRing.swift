import SwiftUI

struct ConfidenceRing: View {
    let confidence: Double // 0...1

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.pepBorder, lineWidth: 5)
            Circle()
                .trim(from: 0, to: confidence)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(confidence * 100))%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.pepTextPrimary)
        }
    }

    private var ringColor: Color {
        if confidence >= 0.75 { return .pepSuccess }
        if confidence >= 0.5 { return .pepWarning }
        return .pepTextTertiary
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        ConfidenceRing(confidence: 0.83)
            .frame(width: 56, height: 56)
        ConfidenceRing(confidence: 0.6)
            .frame(width: 56, height: 56)
        ConfidenceRing(confidence: 0.3)
            .frame(width: 56, height: 56)
    }
    .padding()
    .background(Color.pepBackground)
}
