import SwiftUI

/// 管理棋局状态：棋子、选中、走子、规则校验
class GameState: ObservableObject {
    @Published var pieces: [Piece] = []
    @Published var selectedPieceId: UUID? = nil
    @Published var currentTurn: PieceColor = .red
    @Published var moveHistory: [Move] = []

    struct Move {
        let piece: Piece
        let from: Position
        let to: Position
        let captured: Piece?
    }

    /// 当前选中棋子的合法走法
    var validMoves: [Position] {
        guard let id = selectedPieceId,
              let piece = pieces.first(where: { $0.id == id }) else {
            return []
        }
        return calculateValidMoves(for: piece)
    }

    init() {
        setupInitialPosition()
    }

    // MARK: - 初始局面

    func setupInitialPosition() {
        pieces.removeAll()
        moveHistory.removeAll()
        selectedPieceId = nil
        currentTurn = .red

        // 黑方 (顶部, rows 0-4)
        let blackBackRow: [(PieceType, Int)] = [
            (.chariot, 0), (.horse, 1), (.elephant, 2), (.advisor, 3),
            (.king, 4), (.advisor, 5), (.elephant, 6), (.horse, 7), (.chariot, 8)
        ]
        for (type, col) in blackBackRow {
            pieces.append(Piece(type: type, color: .black, position: Position(row: 0, col: col)))
        }
        pieces.append(Piece(type: .cannon, color: .black, position: Position(row: 2, col: 1)))
        pieces.append(Piece(type: .cannon, color: .black, position: Position(row: 2, col: 7)))
        for col in stride(from: 0, through: 8, by: 2) {
            pieces.append(Piece(type: .pawn, color: .black, position: Position(row: 3, col: col)))
        }

        // 红方 (底部, rows 5-9)
        let redBackRow: [(PieceType, Int)] = [
            (.chariot, 0), (.horse, 1), (.elephant, 2), (.advisor, 3),
            (.king, 4), (.advisor, 5), (.elephant, 6), (.horse, 7), (.chariot, 8)
        ]
        for (type, col) in redBackRow {
            pieces.append(Piece(type: type, color: .red, position: Position(row: 9, col: col)))
        }
        pieces.append(Piece(type: .cannon, color: .red, position: Position(row: 7, col: 1)))
        pieces.append(Piece(type: .cannon, color: .red, position: Position(row: 7, col: 7)))
        for col in stride(from: 0, through: 8, by: 2) {
            pieces.append(Piece(type: .pawn, color: .red, position: Position(row: 6, col: col)))
        }
    }

    // MARK: - 交互

    func piece(at position: Position) -> Piece? {
        pieces.first { $0.position == position }
    }

    /// 点击棋盘上的某个位置：选子或走子
    func selectOrMove(at position: Position) {
        if let selectedId = selectedPieceId {
            if validMoves.contains(position) {
                performMove(to: position)
            } else if let tapped = piece(at: position), tapped.color == currentTurn {
                selectedPieceId = tapped.id
            } else {
                selectedPieceId = nil
            }
        } else {
            if let tapped = piece(at: position), tapped.color == currentTurn {
                selectedPieceId = tapped.id
            }
        }
    }

    private func performMove(to position: Position) {
        guard let selectedId = selectedPieceId,
              let pieceIndex = pieces.firstIndex(where: { $0.id == selectedId }) else { return }

        let movingPiece = pieces[pieceIndex]
        let from = movingPiece.position
        let captured = piece(at: position)

        // 移除被吃的棋子
        if let captured = captured {
            pieces.removeAll { $0.id == captured.id }
        }

        // 移动棋子（注意移除操作可能改变了索引）
        if let newIndex = pieces.firstIndex(where: { $0.id == selectedId }) {
            pieces[newIndex].position = position
        }

        moveHistory.append(Move(piece: movingPiece, from: from, to: position, captured: captured))
        currentTurn = (currentTurn == .red) ? .black : .red
        selectedPieceId = nil
    }

    /// 悔棋
    func undoMove() {
        guard let lastMove = moveHistory.popLast() else { return }

        // 把棋子移回原位
        if let idx = pieces.firstIndex(where: { $0.id == lastMove.piece.id }) {
            pieces[idx].position = lastMove.from
        }

        // 恢复被吃的棋子
        if let captured = lastMove.captured {
            pieces.append(captured)
        }

        currentTurn = (currentTurn == .red) ? .black : .red
        selectedPieceId = nil
    }

    // MARK: - 走子规则

    private func calculateValidMoves(for piece: Piece) -> [Position] {
        let raw: [Position]
        switch piece.type {
        case .king:     raw = kingMoves(for: piece)
        case .advisor:  raw = advisorMoves(for: piece)
        case .elephant: raw = elephantMoves(for: piece)
        case .horse:    raw = horseMoves(for: piece)
        case .chariot:  raw = chariotMoves(for: piece)
        case .cannon:   raw = cannonMoves(for: piece)
        case .pawn:     raw = pawnMoves(for: piece)
        }
        // 过滤掉会导致将帅对面的走法
        return raw.filter { !wouldKingsFace(piece: piece, moveTo: $0) }
    }

    private func isOccupiedByFriend(_ pos: Position, color: PieceColor) -> Bool {
        pieces.contains { $0.position == pos && $0.color == color }
    }

    private func isInPalace(_ pos: Position, for color: PieceColor) -> Bool {
        guard pos.col >= 3 && pos.col <= 5 else { return false }
        return color == .red ? (pos.row >= 7 && pos.row <= 9) : (pos.row >= 0 && pos.row <= 2)
    }

    private func isOnOwnSide(_ pos: Position, for color: PieceColor) -> Bool {
        guard pos.isValid else { return false }
        return color == .red ? pos.row >= 5 : pos.row <= 4
    }

    // MARK: 帅/将

    private func kingMoves(for piece: Piece) -> [Position] {
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        var moves: [Position] = []
        for (dr, dc) in directions {
            let pos = Position(row: piece.position.row + dr, col: piece.position.col + dc)
            if isInPalace(pos, for: piece.color) && !isOccupiedByFriend(pos, color: piece.color) {
                moves.append(pos)
            }
        }
        return moves
    }

    // MARK: 仕/士

    private func advisorMoves(for piece: Piece) -> [Position] {
        let directions = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        var moves: [Position] = []
        for (dr, dc) in directions {
            let pos = Position(row: piece.position.row + dr, col: piece.position.col + dc)
            if isInPalace(pos, for: piece.color) && !isOccupiedByFriend(pos, color: piece.color) {
                moves.append(pos)
            }
        }
        return moves
    }

    // MARK: 相/象

    private func elephantMoves(for piece: Piece) -> [Position] {
        let directions = [(2, 2), (2, -2), (-2, 2), (-2, -2)]
        var moves: [Position] = []
        for (dr, dc) in directions {
            let pos = Position(row: piece.position.row + dr, col: piece.position.col + dc)
            let eye = Position(row: piece.position.row + dr / 2, col: piece.position.col + dc / 2)
            guard pos.isValid else { continue }
            guard isOnOwnSide(pos, for: piece.color) else { continue }  // 不能过河
            guard self.piece(at: eye) == nil else { continue }          // 塞象眼
            if !isOccupiedByFriend(pos, color: piece.color) {
                moves.append(pos)
            }
        }
        return moves
    }

    // MARK: 马

    private func horseMoves(for piece: Piece) -> [Position] {
        // (蹩马腿方向, 目标偏移)
        let steps: [(block: (Int, Int), target: (Int, Int))] = [
            ((-1, 0), (-2, -1)), ((-1, 0), (-2, 1)),  // 向上
            ((1, 0),  (2, -1)),  ((1, 0),  (2, 1)),   // 向下
            ((0, -1), (-1, -2)), ((0, -1), (1, -2)),   // 向左
            ((0, 1),  (-1, 2)),  ((0, 1),  (1, 2)),   // 向右
        ]
        var moves: [Position] = []
        for step in steps {
            let block = Position(row: piece.position.row + step.block.0,
                                 col: piece.position.col + step.block.1)
            let target = Position(row: piece.position.row + step.target.0,
                                  col: piece.position.col + step.target.1)
            guard target.isValid else { continue }
            guard self.piece(at: block) == nil else { continue }  // 蹩马腿
            if !isOccupiedByFriend(target, color: piece.color) {
                moves.append(target)
            }
        }
        return moves
    }

    // MARK: 车

    private func chariotMoves(for piece: Piece) -> [Position] {
        var moves: [Position] = []
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        for (dr, dc) in directions {
            var r = piece.position.row + dr
            var c = piece.position.col + dc
            while Position(row: r, col: c).isValid {
                let pos = Position(row: r, col: c)
                if let p = self.piece(at: pos) {
                    if p.color != piece.color { moves.append(pos) }
                    break
                }
                moves.append(pos)
                r += dr; c += dc
            }
        }
        return moves
    }

    // MARK: 炮

    private func cannonMoves(for piece: Piece) -> [Position] {
        var moves: [Position] = []
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        for (dr, dc) in directions {
            var r = piece.position.row + dr
            var c = piece.position.col + dc
            var jumped = false
            while Position(row: r, col: c).isValid {
                let pos = Position(row: r, col: c)
                if let p = self.piece(at: pos) {
                    if jumped {
                        if p.color != piece.color { moves.append(pos) }
                        break
                    } else {
                        jumped = true  // 炮架
                    }
                } else {
                    if !jumped { moves.append(pos) }
                }
                r += dr; c += dc
            }
        }
        return moves
    }

    // MARK: 兵/卒

    private func pawnMoves(for piece: Piece) -> [Position] {
        var moves: [Position] = []
        let forward = piece.color == .red ? -1 : 1
        let crossed = piece.color == .red ? (piece.position.row <= 4) : (piece.position.row >= 5)

        let fwd = Position(row: piece.position.row + forward, col: piece.position.col)
        if fwd.isValid && !isOccupiedByFriend(fwd, color: piece.color) {
            moves.append(fwd)
        }
        if crossed {
            for dc in [-1, 1] {
                let side = Position(row: piece.position.row, col: piece.position.col + dc)
                if side.isValid && !isOccupiedByFriend(side, color: piece.color) {
                    moves.append(side)
                }
            }
        }
        return moves
    }

    // MARK: - 将帅对面检测

    /// 模拟走子后检查将帅是否对面（同列且中间无子）
    private func wouldKingsFace(piece: Piece, moveTo pos: Position) -> Bool {
        var testPieces = pieces
        // 模拟吃子
        testPieces.removeAll { $0.position == pos && $0.id != piece.id }
        // 模拟移动
        if let idx = testPieces.firstIndex(where: { $0.id == piece.id }) {
            testPieces[idx].position = pos
        }

        guard let redKing = testPieces.first(where: { $0.type == .king && $0.color == .red }),
              let blackKing = testPieces.first(where: { $0.type == .king && $0.color == .black }) else {
            return false
        }
        guard redKing.position.col == blackKing.position.col else { return false }

        let minRow = min(redKing.position.row, blackKing.position.row)
        let maxRow = max(redKing.position.row, blackKing.position.row)
        let col = redKing.position.col

        for row in (minRow + 1)..<maxRow {
            if testPieces.contains(where: { $0.position == Position(row: row, col: col) }) {
                return false
            }
        }
        return true  // 对面了，此走法非法
    }
}
