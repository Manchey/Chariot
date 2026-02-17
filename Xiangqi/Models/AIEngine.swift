import Foundation

/// 象棋 AI 引擎：minimax + alpha-beta 剪枝
class AIEngine {

    enum Difficulty: String, CaseIterable {
        case easy   = "新手"    // depth 1
        case medium = "业余"    // depth 2
        case hard   = "棋手"    // depth 3
    }

    struct AIMove {
        let from: Position
        let to: Position
        let score: Int
    }

    private let difficulty: Difficulty

    init(difficulty: Difficulty = .medium) {
        self.difficulty = difficulty
    }

    private var searchDepth: Int {
        switch difficulty {
        case .easy:   return 1
        case .medium: return 2
        case .hard:   return 3
        }
    }

    /// 为指定颜色选择最佳走法
    func bestMove(pieces: [Piece], for color: PieceColor) -> (from: Position, to: Position)? {
        let depth = searchDepth
        let moves = allMoves(for: color, in: pieces)
        guard !moves.isEmpty else { return nil }

        var bestScore = Int.min
        var bestMoves: [(Position, Position)] = []

        for (from, to) in moves {
            var newPieces = pieces
            applyMove(from: from, to: to, in: &newPieces)
            let score = minimax(pieces: newPieces, depth: depth - 1,
                                alpha: Int.min, beta: Int.max,
                                maximizing: false, aiColor: color)
            if score > bestScore {
                bestScore = score
                bestMoves = [(from, to)]
            } else if score == bestScore {
                bestMoves.append((from, to))
            }
        }

        // 从同分走法中随机选一个，增加变化
        return bestMoves.randomElement()
    }

    // MARK: - Minimax + Alpha-Beta

    private func minimax(pieces: [Piece], depth: Int, alpha: Int, beta: Int,
                         maximizing: Bool, aiColor: PieceColor) -> Int {
        if depth == 0 {
            return evaluate(pieces: pieces, for: aiColor)
        }

        let color = maximizing ? aiColor : (aiColor == .red ? .black : .red)
        let moves = allMoves(for: color, in: pieces)

        // 无子可走
        if moves.isEmpty {
            return maximizing ? -90000 : 90000
        }

        if maximizing {
            var maxEval = Int.min
            var a = alpha
            for (from, to) in moves {
                var newPieces = pieces
                let captured = applyMove(from: from, to: to, in: &newPieces)
                // 吃到将/帅，直接返回极值
                if captured?.type == .king {
                    return 100000
                }
                let eval = minimax(pieces: newPieces, depth: depth - 1,
                                   alpha: a, beta: beta,
                                   maximizing: false, aiColor: aiColor)
                maxEval = max(maxEval, eval)
                a = max(a, eval)
                if beta <= a { break }
            }
            return maxEval
        } else {
            var minEval = Int.max
            var b = beta
            for (from, to) in moves {
                var newPieces = pieces
                let captured = applyMove(from: from, to: to, in: &newPieces)
                if captured?.type == .king {
                    return -100000
                }
                let eval = minimax(pieces: newPieces, depth: depth - 1,
                                   alpha: alpha, beta: b,
                                   maximizing: true, aiColor: aiColor)
                minEval = min(minEval, eval)
                b = min(b, eval)
                if b <= alpha { break }
            }
            return minEval
        }
    }

    // MARK: - 局面评估

    private func evaluate(pieces: [Piece], for aiColor: PieceColor) -> Int {
        var score = 0
        for piece in pieces {
            let value = materialValue(piece.type) + positionValue(piece)
            if piece.color == aiColor {
                score += value
            } else {
                score -= value
            }
        }
        return score
    }

    private func materialValue(_ type: PieceType) -> Int {
        switch type {
        case .king:     return 10000
        case .chariot:  return 1000
        case .cannon:   return 500
        case .horse:    return 450
        case .elephant: return 200
        case .advisor:  return 200
        case .pawn:     return 100
        }
    }

    /// 位置加分：鼓励棋子占据好位置
    private func positionValue(_ piece: Piece) -> Int {
        let row = piece.position.row
        let col = piece.position.col

        switch piece.type {
        case .pawn:
            // 过河兵/卒价值翻倍
            let crossed = piece.color == .red ? (row <= 4) : (row >= 5)
            if crossed {
                // 越靠近对方底线越值钱，中路兵更有价值
                let advanceBonus = piece.color == .red ? (4 - row) * 15 : (row - 5) * 15
                let centerBonus = (4 - abs(col - 4)) * 5
                return 100 + advanceBonus + centerBonus
            }
            return 0

        case .horse:
            // 马在中心位置更灵活
            let centerBonus = (4 - abs(col - 4)) * 10 + (4 - abs(row - 4)) * 5
            return centerBonus

        case .chariot:
            // 车占据开放线和要道
            let centerBonus = (4 - abs(col - 4)) * 5
            return centerBonus

        case .cannon:
            // 炮在后方更有价值
            let backBonus = piece.color == .red ? (row - 5) * 8 : (4 - row) * 8
            return max(0, backBonus)

        default:
            return 0
        }
    }

    // MARK: - 走法生成

    private func allMoves(for color: PieceColor, in pieces: [Piece]) -> [(Position, Position)] {
        var moves: [(Position, Position)] = []
        for piece in pieces where piece.color == color {
            let targets = validMoves(for: piece, in: pieces)
            for target in targets {
                moves.append((piece.position, target))
            }
        }
        // 优先吃子走法（改善剪枝效率）
        moves.sort { m1, m2 in
            let c1 = pieces.contains { $0.position == m1.1 && $0.color != color }
            let c2 = pieces.contains { $0.position == m2.1 && $0.color != color }
            if c1 && !c2 { return true }
            if !c1 && c2 { return false }
            return false
        }
        return moves
    }

    @discardableResult
    private func applyMove(from: Position, to: Position, in pieces: inout [Piece]) -> Piece? {
        let captured = pieces.first { $0.position == to }
        if captured != nil {
            pieces.removeAll { $0.position == to }
        }
        if let idx = pieces.firstIndex(where: { $0.position == from }) {
            pieces[idx].position = to
        }
        return captured
    }

    // MARK: - 走子规则（复用 GameState 的逻辑）

    private func validMoves(for piece: Piece, in pieces: [Piece]) -> [Position] {
        switch piece.type {
        case .king:     return kingMoves(for: piece, in: pieces)
        case .advisor:  return advisorMoves(for: piece, in: pieces)
        case .elephant: return elephantMoves(for: piece, in: pieces)
        case .horse:    return horseMoves(for: piece, in: pieces)
        case .chariot:  return chariotMoves(for: piece, in: pieces)
        case .cannon:   return cannonMoves(for: piece, in: pieces)
        case .pawn:     return pawnMoves(for: piece, in: pieces)
        }
    }

    private func isOccupiedByFriend(_ pos: Position, color: PieceColor, in pieces: [Piece]) -> Bool {
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

    private func kingMoves(for piece: Piece, in pieces: [Piece]) -> [Position] {
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        var moves: [Position] = []
        for (dr, dc) in directions {
            let pos = Position(row: piece.position.row + dr, col: piece.position.col + dc)
            if isInPalace(pos, for: piece.color) && !isOccupiedByFriend(pos, color: piece.color, in: pieces) {
                moves.append(pos)
            }
        }
        return moves
    }

    private func advisorMoves(for piece: Piece, in pieces: [Piece]) -> [Position] {
        let directions = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        var moves: [Position] = []
        for (dr, dc) in directions {
            let pos = Position(row: piece.position.row + dr, col: piece.position.col + dc)
            if isInPalace(pos, for: piece.color) && !isOccupiedByFriend(pos, color: piece.color, in: pieces) {
                moves.append(pos)
            }
        }
        return moves
    }

    private func elephantMoves(for piece: Piece, in pieces: [Piece]) -> [Position] {
        let directions = [(2, 2), (2, -2), (-2, 2), (-2, -2)]
        var moves: [Position] = []
        for (dr, dc) in directions {
            let pos = Position(row: piece.position.row + dr, col: piece.position.col + dc)
            let eye = Position(row: piece.position.row + dr / 2, col: piece.position.col + dc / 2)
            guard pos.isValid, isOnOwnSide(pos, for: piece.color) else { continue }
            guard !pieces.contains(where: { $0.position == eye }) else { continue }
            if !isOccupiedByFriend(pos, color: piece.color, in: pieces) {
                moves.append(pos)
            }
        }
        return moves
    }

    private func horseMoves(for piece: Piece, in pieces: [Piece]) -> [Position] {
        let steps: [(block: (Int, Int), target: (Int, Int))] = [
            ((-1, 0), (-2, -1)), ((-1, 0), (-2, 1)),
            ((1, 0),  (2, -1)),  ((1, 0),  (2, 1)),
            ((0, -1), (-1, -2)), ((0, -1), (1, -2)),
            ((0, 1),  (-1, 2)),  ((0, 1),  (1, 2)),
        ]
        var moves: [Position] = []
        for step in steps {
            let block = Position(row: piece.position.row + step.block.0,
                                 col: piece.position.col + step.block.1)
            let target = Position(row: piece.position.row + step.target.0,
                                  col: piece.position.col + step.target.1)
            guard target.isValid else { continue }
            guard !pieces.contains(where: { $0.position == block }) else { continue }
            if !isOccupiedByFriend(target, color: piece.color, in: pieces) {
                moves.append(target)
            }
        }
        return moves
    }

    private func chariotMoves(for piece: Piece, in pieces: [Piece]) -> [Position] {
        var moves: [Position] = []
        for (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)] {
            var r = piece.position.row + dr
            var c = piece.position.col + dc
            while Position(row: r, col: c).isValid {
                let pos = Position(row: r, col: c)
                if let p = pieces.first(where: { $0.position == pos }) {
                    if p.color != piece.color { moves.append(pos) }
                    break
                }
                moves.append(pos)
                r += dr; c += dc
            }
        }
        return moves
    }

    private func cannonMoves(for piece: Piece, in pieces: [Piece]) -> [Position] {
        var moves: [Position] = []
        for (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)] {
            var r = piece.position.row + dr
            var c = piece.position.col + dc
            var jumped = false
            while Position(row: r, col: c).isValid {
                let pos = Position(row: r, col: c)
                if let p = pieces.first(where: { $0.position == pos }) {
                    if jumped {
                        if p.color != piece.color { moves.append(pos) }
                        break
                    } else {
                        jumped = true
                    }
                } else {
                    if !jumped { moves.append(pos) }
                }
                r += dr; c += dc
            }
        }
        return moves
    }

    private func pawnMoves(for piece: Piece, in pieces: [Piece]) -> [Position] {
        var moves: [Position] = []
        let forward = piece.color == .red ? -1 : 1
        let crossed = piece.color == .red ? (piece.position.row <= 4) : (piece.position.row >= 5)
        let fwd = Position(row: piece.position.row + forward, col: piece.position.col)
        if fwd.isValid && !isOccupiedByFriend(fwd, color: piece.color, in: pieces) {
            moves.append(fwd)
        }
        if crossed {
            for dc in [-1, 1] {
                let side = Position(row: piece.position.row, col: piece.position.col + dc)
                if side.isValid && !isOccupiedByFriend(side, color: piece.color, in: pieces) {
                    moves.append(side)
                }
            }
        }
        return moves
    }
}
