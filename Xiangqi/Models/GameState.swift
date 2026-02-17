import SwiftUI

/// 管理棋局状态：棋子、选中、走子、规则校验
class GameState: ObservableObject {
    @Published var pieces: [Piece] = []
    @Published var selectedPieceId: UUID? = nil
    @Published var currentTurn: PieceColor = .red
    @Published var moveHistory: [Move] = []
    @Published var isCheck: Bool = false
    @Published var isGameOver: Bool = false
    @Published var winner: PieceColor? = nil

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
        isCheck = false
        isGameOver = false
        winner = nil

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
        guard !isGameOver else { return }
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

        // 检查对方是否被将军或将死/困毙
        if isInCheck(currentTurn) {
            isCheck = true
            if !hasLegalMoves(for: currentTurn) {
                isGameOver = true
                winner = (currentTurn == .red) ? .black : .red
            }
        } else {
            isCheck = false
            if !hasLegalMoves(for: currentTurn) {
                // 困毙：未被将军但无合法走法
                isGameOver = true
                winner = (currentTurn == .red) ? .black : .red
            }
        }
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
        isGameOver = false
        winner = nil
        isCheck = isInCheck(currentTurn)
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
        // 过滤掉会导致己方被将军的走法（包括将帅对面）
        return raw.filter { !wouldBeInCheck(piece: piece, moveTo: $0) }
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

    // MARK: - 将军 / 将死检测

    /// 检查指定颜色是否正在被将军
    func isInCheck(_ color: PieceColor) -> Bool {
        guard let king = pieces.first(where: { $0.type == .king && $0.color == color }) else {
            return false
        }
        let enemyColor: PieceColor = color == .red ? .black : .red
        if isAttacked(king.position, by: enemyColor, in: pieces) { return true }
        if kingsFacing(in: pieces) { return true }
        return false
    }

    /// 检查指定颜色是否还有合法走法
    private func hasLegalMoves(for color: PieceColor) -> Bool {
        for p in pieces where p.color == color {
            if !calculateValidMoves(for: p).isEmpty { return true }
        }
        return false
    }

    /// 模拟走子后检查己方是否被将军（非法走法过滤）
    private func wouldBeInCheck(piece: Piece, moveTo pos: Position) -> Bool {
        let testPieces = simulateMove(piece: piece, to: pos)

        guard let ownKing = testPieces.first(where: { $0.type == .king && $0.color == piece.color }) else {
            return true
        }
        let enemyColor: PieceColor = piece.color == .red ? .black : .red

        if isAttacked(ownKing.position, by: enemyColor, in: testPieces) { return true }
        if kingsFacing(in: testPieces) { return true }
        return false
    }

    /// 模拟一步走子，返回走后的棋子数组
    private func simulateMove(piece: Piece, to pos: Position) -> [Piece] {
        var testPieces = pieces
        testPieces.removeAll { $0.position == pos && $0.id != piece.id }
        if let idx = testPieces.firstIndex(where: { $0.id == piece.id }) {
            testPieces[idx].position = pos
        }
        return testPieces
    }

    /// 检查某个位置是否被指定颜色的棋子攻击
    private func isAttacked(_ pos: Position, by attackerColor: PieceColor, in boardPieces: [Piece]) -> Bool {
        for p in boardPieces where p.color == attackerColor {
            if canReach(piece: p, target: pos, in: boardPieces) { return true }
        }
        return false
    }

    /// 纯规则判断：某个棋子能否到达目标位置（不考虑将军限制）
    private func canReach(piece p: Piece, target: Position, in bp: [Piece]) -> Bool {
        guard target.isValid else { return false }
        if bp.contains(where: { $0.position == target && $0.color == p.color }) { return false }

        let dr = target.row - p.position.row
        let dc = target.col - p.position.col

        switch p.type {
        case .king:
            return (abs(dr) + abs(dc) == 1) && isInPalace(target, for: p.color)

        case .advisor:
            return abs(dr) == 1 && abs(dc) == 1 && isInPalace(target, for: p.color)

        case .elephant:
            guard abs(dr) == 2 && abs(dc) == 2 else { return false }
            guard isOnOwnSide(target, for: p.color) else { return false }
            let eye = Position(row: p.position.row + dr / 2, col: p.position.col + dc / 2)
            return !bp.contains { $0.position == eye }

        case .horse:
            let steps: [(block: (Int, Int), target: (Int, Int))] = [
                ((-1, 0), (-2, -1)), ((-1, 0), (-2, 1)),
                ((1, 0),  (2, -1)),  ((1, 0),  (2, 1)),
                ((0, -1), (-1, -2)), ((0, -1), (1, -2)),
                ((0, 1),  (-1, 2)),  ((0, 1),  (1, 2)),
            ]
            for step in steps {
                let t = Position(row: p.position.row + step.target.0,
                                 col: p.position.col + step.target.1)
                if t == target {
                    let block = Position(row: p.position.row + step.block.0,
                                         col: p.position.col + step.block.1)
                    return !bp.contains { $0.position == block }
                }
            }
            return false

        case .chariot:
            guard dr == 0 || dc == 0 else { return false }
            return countBetween(from: p.position, to: target, in: bp) == 0

        case .cannon:
            guard dr == 0 || dc == 0 else { return false }
            let between = countBetween(from: p.position, to: target, in: bp)
            let isCapture = bp.contains { $0.position == target }
            return isCapture ? (between == 1) : (between == 0)

        case .pawn:
            let forward = p.color == .red ? -1 : 1
            let crossed = p.color == .red ? (p.position.row <= 4) : (p.position.row >= 5)
            if dr == forward && dc == 0 { return true }
            if crossed && dr == 0 && abs(dc) == 1 { return true }
            return false
        }
    }

    /// 两点之间（同行或同列）的棋子数量
    private func countBetween(from: Position, to: Position, in bp: [Piece]) -> Int {
        var count = 0
        if from.row == to.row {
            let lo = min(from.col, to.col), hi = max(from.col, to.col)
            for c in (lo + 1)..<hi {
                if bp.contains(where: { $0.position.row == from.row && $0.position.col == c }) { count += 1 }
            }
        } else {
            let lo = min(from.row, to.row), hi = max(from.row, to.row)
            for r in (lo + 1)..<hi {
                if bp.contains(where: { $0.position.row == r && $0.position.col == from.col }) { count += 1 }
            }
        }
        return count
    }

    /// 检查将帅是否在同列且中间无子（对面）
    private func kingsFacing(in bp: [Piece]) -> Bool {
        guard let redKing = bp.first(where: { $0.type == .king && $0.color == .red }),
              let blackKing = bp.first(where: { $0.type == .king && $0.color == .black }) else {
            return false
        }
        guard redKing.position.col == blackKing.position.col else { return false }
        let minRow = min(redKing.position.row, blackKing.position.row)
        let maxRow = max(redKing.position.row, blackKing.position.row)
        for row in (minRow + 1)..<maxRow {
            if bp.contains(where: { $0.position == Position(row: row, col: redKing.position.col) }) {
                return false
            }
        }
        return true
    }
}
