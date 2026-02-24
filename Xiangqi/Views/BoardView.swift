import SwiftUI

/// 绘制棋盘网格：横线、纵线、河界、九宫格斜线
struct BoardCanvasView: View {
    let cellSize: CGFloat
    let padding: CGFloat

    private var boardWidth: CGFloat { 8.0 * cellSize }
    private var boardHeight: CGFloat { 9.0 * cellSize }

    var body: some View {
        Canvas { context, _ in
            // 棋盘底色
            let bgRect = CGRect(x: padding - 20, y: padding - 20,
                                width: boardWidth + 40, height: boardHeight + 40)
            context.fill(Path(roundedRect: bgRect, cornerRadius: 4),
                         with: .color(Color(red: 0.87, green: 0.72, blue: 0.53)))

            // 外边框
            let borderRect = CGRect(x: padding - 4, y: padding - 4,
                                    width: boardWidth + 8, height: boardHeight + 8)
            context.stroke(Path(borderRect),
                           with: .color(Color(red: 0.35, green: 0.20, blue: 0.10)),
                           lineWidth: 3)

            var gridPath = Path()

            // 10 条横线（全宽）
            for row in 0...9 {
                let y = padding + CGFloat(row) * cellSize
                gridPath.move(to: CGPoint(x: padding, y: y))
                gridPath.addLine(to: CGPoint(x: padding + boardWidth, y: y))
            }

            // 左右边线（全高）
            for col in [0, 8] {
                let x = padding + CGFloat(col) * cellSize
                gridPath.move(to: CGPoint(x: x, y: padding))
                gridPath.addLine(to: CGPoint(x: x, y: padding + boardHeight))
            }

            // 中间纵线：上半部 row 0→4，下半部 row 5→9（河界断开）
            for col in 1...7 {
                let x = padding + CGFloat(col) * cellSize
                gridPath.move(to: CGPoint(x: x, y: padding))
                gridPath.addLine(to: CGPoint(x: x, y: padding + 4 * cellSize))
                gridPath.move(to: CGPoint(x: x, y: padding + 5 * cellSize))
                gridPath.addLine(to: CGPoint(x: x, y: padding + boardHeight))
            }

            let lineColor = Color(red: 0.35, green: 0.20, blue: 0.10)
            context.stroke(gridPath, with: .color(lineColor), lineWidth: 1.2)

            // 九宫格斜线
            var palacePath = Path()
            // 黑方九宫 (rows 0-2, cols 3-5)
            palacePath.move(to: point(3, 0))
            palacePath.addLine(to: point(5, 2))
            palacePath.move(to: point(5, 0))
            palacePath.addLine(to: point(3, 2))
            // 红方九宫 (rows 7-9, cols 3-5)
            palacePath.move(to: point(3, 7))
            palacePath.addLine(to: point(5, 9))
            palacePath.move(to: point(5, 7))
            palacePath.addLine(to: point(3, 9))

            context.stroke(palacePath, with: .color(lineColor), lineWidth: 1.2)

            // 河界文字
            let riverY = padding + 4.5 * cellSize
            context.draw(
                Text("楚 河")
                    .font(.system(size: min(cellSize * 0.45, 26), weight: .medium, design: .serif))
                    .foregroundColor(lineColor),
                at: CGPoint(x: padding + 2 * cellSize, y: riverY))
            context.draw(
                Text("漢 界")
                    .font(.system(size: min(cellSize * 0.45, 26), weight: .medium, design: .serif))
                    .foregroundColor(lineColor),
                at: CGPoint(x: padding + 6 * cellSize, y: riverY))
        }
    }

    private func point(_ col: Int, _ row: Int) -> CGPoint {
        CGPoint(x: padding + CGFloat(col) * cellSize,
                y: padding + CGFloat(row) * cellSize)
    }
}

/// 单个棋子的视图
struct PieceView: View {
    let piece: Piece
    let isSelected: Bool
    var isLastMoved: Bool = false
    let size: CGFloat
    var isFlipped: Bool = false

    var body: some View {
        let pieceColor: Color = piece.color == .red
            ? Color(red: 0.80, green: 0.10, blue: 0.10)
            : Color(red: 0.15, green: 0.15, blue: 0.15)

        ZStack {
            // 底色圆
            Circle()
                .fill(Color(red: 0.96, green: 0.88, blue: 0.72))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)

            // 外圈
            Circle()
                .stroke(pieceColor, lineWidth: 2)
                .frame(width: size - 6, height: size - 6)

            // 文字
            Text(piece.displayName)
                .font(.system(size: size * 0.52, weight: .bold, design: .serif))
                .foregroundColor(pieceColor)
        }
        .overlay(
            Circle()
                .stroke(Color.yellow, lineWidth: 3)
                .frame(width: size + 4, height: size + 4)
                .opacity(isSelected ? 1 : 0)
        )
        .overlay(
            Circle()
                .stroke(Color.cyan.opacity(0.9), lineWidth: 3)
                .frame(width: size + 10, height: size + 10)
                .opacity(isLastMoved ? 1 : 0)
        )
        .shadow(color: isLastMoved ? Color.cyan.opacity(0.35) : .clear,
                radius: isLastMoved ? 10 : 0)
        .rotationEffect(isFlipped ? .degrees(180) : .zero)
    }
}
