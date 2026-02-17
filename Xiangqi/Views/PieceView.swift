import SwiftUI

/// 棋盘 + 棋子 + 交互的组合视图
struct GameBoardView: View {
    @ObservedObject var gameState: GameState
    let cellSize: CGFloat
    let padding: CGFloat

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
                lastMoveMarker.position(pointFor(from))
            }
            if let to = gameState.lastMoveTo {
                lastMoveMarker.position(pointFor(to))
            }

            // 合法走法指示器（对弈模式和残局模式）
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

    /// 上一步走子的半透明方形标记
    private var lastMoveMarker: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.yellow.opacity(0.35))
            .frame(width: cellSize * 0.7, height: cellSize * 0.7)
    }

    private func piece(at pos: Position) -> Piece? {
        gameState.pieces.first { $0.position == pos }
    }

    private func pointFor(_ pos: Position) -> CGPoint {
        CGPoint(x: padding + CGFloat(pos.col) * cellSize,
                y: padding + CGFloat(pos.row) * cellSize)
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
