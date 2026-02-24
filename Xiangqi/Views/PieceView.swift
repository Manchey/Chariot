import SwiftUI

/// 棋盘 + 棋子 + 交互的组合视图
struct GameBoardView: View {
    @ObservedObject var gameState: GameState
    let cellSize: CGFloat
    let padding: CGFloat
    var hintMoves: [AIEngine.ScoredMove] = []

    private var boardWidth: CGFloat { 8.0 * cellSize }
    private var boardHeight: CGFloat { 9.0 * cellSize }
    private var totalWidth: CGFloat { boardWidth + padding * 2 }
    private var totalHeight: CGFloat { boardHeight + padding * 2 }
    private var pieceSize: CGFloat { cellSize * 0.85 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 棋盘底图
            BoardCanvasView(cellSize: cellSize, padding: padding)

            // 上一步走法高亮
            if let from = gameState.lastMoveFrom {
                moveCornerMarker.position(pointFor(from))
            }
            if let to = gameState.lastMoveTo {
                moveCornerMarker.position(pointFor(to))
            }

            hintArrowsLayer

            // 合法走法指示器
            ForEach(gameState.validMoves, id: \.self) { pos in
                let target = piece(at: pos)
                Group {
                    if target != nil {
                        Circle()
                            .stroke(Color.red.opacity(0.6), lineWidth: 3)
                            .frame(width: pieceSize, height: pieceSize)
                    } else {
                        Circle()
                            .fill(Color.green.opacity(0.5))
                            .frame(width: cellSize * 0.25, height: cellSize * 0.25)
                    }
                }
                .position(pointFor(pos))
            }

            // 棋子
            ForEach(gameState.pieces) { piece in
                PieceView(piece: piece,
                          isSelected: piece.id == gameState.selectedPieceId,
                          size: pieceSize,
                          isFlipped: gameState.isBoardFlipped)
                    .position(pointFor(piece.position))
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .rotationEffect(gameState.isBoardFlipped ? .degrees(180) : .zero)
        .animation(.easeInOut(duration: 0.4), value: gameState.isBoardFlipped)
        .contentShape(Rectangle())
        .onTapGesture { location in
            let adjusted = adjustedPoint(location)
            if let pos = positionFor(point: adjusted) {
                gameState.selectOrMove(at: pos)
            }
        }
    }

    /// 上一步走子位置的低调四角标记
    private var moveCornerMarker: some View {
        let markerSize = cellSize * 0.88
        return ZStack {
            Color.clear
        }
        .frame(width: markerSize, height: markerSize)
        .overlay(alignment: .topLeading) { cornerLShape(rotation: 0) }
        .overlay(alignment: .topTrailing) { cornerLShape(rotation: 90) }
        .overlay(alignment: .bottomTrailing) { cornerLShape(rotation: 180) }
        .overlay(alignment: .bottomLeading) { cornerLShape(rotation: 270) }
    }

    private var hintArrowsLayer: some View {
        Canvas { context, _ in
            for (index, hint) in hintMoves.enumerated() {
                let from = pointFor(hint.from)
                let to = pointFor(hint.to)
                let strength: CGFloat = [1.0, 0.7, 0.45][min(index, 2)]
                let arrowColor = Color.blue.opacity(0.9 * strength)
                let lineWidth: CGFloat = [3.6, 2.8, 2.2][min(index, 2)]

                let dx = to.x - from.x
                let dy = to.y - from.y
                let len = max(1, sqrt(dx * dx + dy * dy))
                let ux = dx / len
                let uy = dy / len
                let start = CGPoint(x: from.x + ux * (pieceSize * 0.35),
                                    y: from.y + uy * (pieceSize * 0.35))
                let end = CGPoint(x: to.x - ux * (pieceSize * 0.45),
                                  y: to.y - uy * (pieceSize * 0.45))

                var line = Path()
                line.move(to: start)
                line.addLine(to: end)
                context.stroke(line, with: .color(arrowColor),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                let headLength = cellSize * 0.22
                let headWidth = cellSize * 0.14
                let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)
                let px = -uy
                let py = ux
                let left = CGPoint(x: base.x + px * headWidth, y: base.y + py * headWidth)
                let right = CGPoint(x: base.x - px * headWidth, y: base.y - py * headWidth)

                var head = Path()
                head.move(to: end)
                head.addLine(to: left)
                head.addLine(to: right)
                head.closeSubpath()
                context.fill(head, with: .color(arrowColor))

                let labelCenter = CGPoint(x: start.x - px * cellSize * 0.16,
                                          y: start.y - py * cellSize * 0.16)
                let labelRect = CGRect(x: labelCenter.x - cellSize * 0.14,
                                       y: labelCenter.y - cellSize * 0.14,
                                       width: cellSize * 0.28,
                                       height: cellSize * 0.28)
                context.fill(Path(ellipseIn: labelRect), with: .color(Color.blue.opacity(0.18 * strength)))
                context.stroke(Path(ellipseIn: labelRect), with: .color(arrowColor), lineWidth: 2)
                context.draw(
                    Text("\(index + 1)")
                        .font(.system(size: cellSize * 0.18, weight: .bold))
                        .foregroundColor(.white),
                    at: labelCenter
                )
            }
        }
    }

    private func piece(at pos: Position) -> Piece? {
        gameState.pieces.first { $0.position == pos }
    }

    private func pointFor(_ pos: Position) -> CGPoint {
        CGPoint(x: padding + CGFloat(pos.col) * cellSize,
                y: padding + CGFloat(pos.row) * cellSize)
    }

    private func cornerLShape(rotation: Double) -> some View {
        let arm = cellSize * 0.18
        let color = Color(red: 0.18, green: 0.45, blue: 0.55).opacity(0.65)

        return Path { path in
            path.move(to: CGPoint(x: 0, y: arm))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: arm, y: 0))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        .frame(width: arm, height: arm, alignment: .topLeading)
        .rotationEffect(.degrees(rotation))
    }

    /// 翻转时将点击坐标转换回正常坐标
    private func adjustedPoint(_ point: CGPoint) -> CGPoint {
        if gameState.isBoardFlipped {
            return CGPoint(x: totalWidth - point.x, y: totalHeight - point.y)
        }
        return point
    }

    private func positionFor(point: CGPoint) -> Position? {
        let col = Int(round((point.x - padding) / cellSize))
        let row = Int(round((point.y - padding) / cellSize))
        let pos = Position(row: row, col: col)
        return pos.isValid ? pos : nil
    }
}
