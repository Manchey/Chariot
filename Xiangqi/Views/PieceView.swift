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

            // 合法走法指示器
            ForEach(gameState.validMoves, id: \.self) { pos in
                let target = piece(at: pos)
                Group {
                    if target != nil {
                        // 可以吃子：红色圆环
                        Circle()
                            .stroke(Color.red.opacity(0.6), lineWidth: 3)
                            .frame(width: pieceSize, height: pieceSize)
                    } else {
                        // 可以移动：绿色小圆点
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
                          size: pieceSize)
                    .position(pointFor(piece.position))
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .contentShape(Rectangle())
        .onTapGesture { location in
            if let pos = positionFor(point: location) {
                gameState.selectOrMove(at: pos)
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

    private func positionFor(point: CGPoint) -> Position? {
        let col = Int(round((point.x - padding) / cellSize))
        let row = Int(round((point.y - padding) / cellSize))
        let pos = Position(row: row, col: col)
        return pos.isValid ? pos : nil
    }
}
