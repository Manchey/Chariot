import SwiftUI

/// 局面评估条：红色在下，黑色在上，比例反映优劣势
struct EvaluationBarView: View {
    let score: Int  // 红方视角，正值红优

    private var redRatio: CGFloat {
        // 将分数映射到 0-1，0.5 为均势
        let clamped = max(-3000, min(3000, Double(score)))
        return CGFloat(0.5 + clamped / 6000.0)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 黑方区域（上方）
                Rectangle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .frame(height: geo.size.height * (1 - redRatio))

                // 红方区域（下方）
                Rectangle()
                    .fill(Color(red: 0.80, green: 0.10, blue: 0.10))
                    .frame(height: geo.size.height * redRatio)
            }
            .overlay(
                // 分值标签
                Text(scoreLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 2)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(2)
                    .position(x: geo.size.width / 2,
                              y: geo.size.height * (1 - redRatio))
            )
        }
        .frame(width: 24)
        .cornerRadius(4)
        .animation(.easeInOut(duration: 0.5), value: score)
    }

    private var scoreLabel: String {
        if score > 0 {
            return "+\(score)"
        } else {
            return "\(score)"
        }
    }
}
