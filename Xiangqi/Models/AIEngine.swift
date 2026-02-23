import Foundation

/// 象棋 AI 引擎：Pikafish UCI 优先，minimax 回退
class AIEngine {

    enum Difficulty: String, CaseIterable {
        case beginner = "入门"    // Skill Level 0
        case easy     = "新手"    // Skill Level 3
        case medium   = "业余"    // Skill Level 8
        case advanced = "棋手"    // Skill Level 12
        case hard     = "高手"    // Skill Level 16
        case expert   = "大师"    // Skill Level 19
        case master   = "特级"    // Skill Level 20

        var skillLevel: Int {
            switch self {
            case .beginner: return 0
            case .easy:     return 3
            case .medium:   return 8
            case .advanced: return 12
            case .hard:     return 16
            case .expert:   return 19
            case .master:   return 20
            }
        }

        var pikaDepth: Int {
            switch self {
            case .beginner: return 6
            case .easy:     return 8
            case .medium:   return 12
            case .advanced: return 16
            case .hard:     return 20
            case .expert:   return 24
            case .master:   return 28
            }
        }

        var minimaxDepth: Int {
            switch self {
            case .beginner, .easy: return 1
            case .medium, .advanced: return 2
            case .hard, .expert, .master: return 3
            }
        }
    }

    struct AIMove {
        let from: Position
        let to: Position
        let score: Int
    }

    struct ScoredMove {
        let from: Position
        let to: Position
        let score: Int
    }

    private let difficulty: Difficulty

    // 共享 UCI 引擎实例
    private static var sharedUCIEngine: UCIEngine?
    private static var uciAvailable = false
    private static var uciInitialized = false
    private static let initLock = NSLock()

    init(difficulty: Difficulty = .medium) {
        self.difficulty = difficulty
        Self.initializeUCIIfNeeded()
    }

    // MARK: - UCI 初始化

    private static func initializeUCIIfNeeded() {
        initLock.lock()
        defer { initLock.unlock() }
        guard !uciInitialized else { return }
        uciInitialized = true

        guard UCIEngine.isAvailable else {
            uciAvailable = false
            return
        }

        let engine = UCIEngine()
        let sem = DispatchSemaphore(value: 0)
        engine.start { result in
            switch result {
            case .success:
                sharedUCIEngine = engine
                uciAvailable = true
            case .failure:
                uciAvailable = false
            }
            sem.signal()
        }
        // 等待最多 10 秒
        _ = sem.wait(timeout: .now() + .seconds(10))
    }

    static var isUCIEngineAvailable: Bool { uciAvailable }

    static func shutdownEngine() {
        sharedUCIEngine?.shutdown()
        sharedUCIEngine = nil
        uciAvailable = false
    }

    static func resetForNewGame() {
        sharedUCIEngine?.newGame()
    }

    // MARK: - 公开方法（保持签名不变，同步，须在后台线程调用）

    func bestMove(pieces: [Piece], for color: PieceColor) -> (from: Position, to: Position)? {
        if Self.uciAvailable, let engine = Self.sharedUCIEngine {
            configureSkillLevel(engine)
            let fen = FENParser.generate(pieces: pieces, turn: color)
            if let result = engine.searchBestMoveSync(fen: fen, depth: difficulty.pikaDepth),
               let move = ICCSNotation.parseMove(result.bestMove) {
                return move
            }
        }
        return bestMoveMinimax(pieces: pieces, for: color)
    }

    func topMoves(pieces: [Piece], for color: PieceColor, count: Int, depth: Int) -> [ScoredMove] {
        if Self.uciAvailable, let engine = Self.sharedUCIEngine {
            let fen = FENParser.generate(pieces: pieces, turn: color)
            let pikaDepth = Self.uciAvailable ? max(depth, 12) : depth
            let result = engine.searchMultiPVSync(fen: fen, pvCount: count, depth: pikaDepth)
            let moves = result.lines.compactMap { line -> ScoredMove? in
                guard let firstMove = line.moves.first,
                      let move = ICCSNotation.parseMove(firstMove) else { return nil }
                return ScoredMove(from: move.from, to: move.to, score: line.score)
            }
            if !moves.isEmpty { return moves }
        }
        return topMovesMinimax(pieces: pieces, for: color, count: count, depth: depth)
    }

    func deepEvaluate(pieces: [Piece], for color: PieceColor, depth: Int) -> Int {
        if Self.uciAvailable, let engine = Self.sharedUCIEngine {
            let fen = FENParser.generate(pieces: pieces, turn: color)
            let pikaDepth = Self.uciAvailable ? max(depth, 10) : depth
            if let result = engine.searchBestMoveSync(fen: fen, depth: pikaDepth) {
                // 引擎分数是走子方视角，转为红方视角
                return color == .red ? result.score : -result.score
            }
        }
        return deepEvaluateMinimax(pieces: pieces, for: color, depth: depth)
    }

    private func configureSkillLevel(_ engine: UCIEngine) {
        engine.setSkillLevel(difficulty.skillLevel)
    }

    // MARK: - Minimax 回退实现

    private func bestMoveMinimax(pieces: [Piece], for color: PieceColor) -> (from: Position, to: Position)? {
        let depth = difficulty.minimaxDepth
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

        return bestMoves.randomElement()
    }

    private func topMovesMinimax(pieces: [Piece], for color: PieceColor, count: Int, depth: Int) -> [ScoredMove] {
        let moves = allMoves(for: color, in: pieces)
        guard !moves.isEmpty else { return [] }

        var scored: [ScoredMove] = []
        for (from, to) in moves {
            var newPieces = pieces
            let captured = applyMove(from: from, to: to, in: &newPieces)
            let score: Int
            if captured?.type == .king {
                score = 100000
            } else {
                score = minimax(pieces: newPieces, depth: depth - 1,
                                alpha: Int.min, beta: Int.max,
                                maximizing: false, aiColor: color)
            }
            scored.append(ScoredMove(from: from, to: to, score: score))
        }

        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(count))
    }

    private func deepEvaluateMinimax(pieces: [Piece], for color: PieceColor, depth: Int) -> Int {
        let score = minimax(pieces: pieces, depth: depth,
                            alpha: Int.min, beta: Int.max,
                            maximizing: true, aiColor: color)
        return color == .red ? score : -score
    }

    // MARK: - Minimax + Alpha-Beta

    private func minimax(pieces: [Piece], depth: Int, alpha: Int, beta: Int,
                         maximizing: Bool, aiColor: PieceColor) -> Int {
        if depth == 0 {
            return evaluate(pieces: pieces, for: aiColor)
        }

        let color = maximizing ? aiColor : (aiColor == .red ? .black : .red)
        let moves = allMoves(for: color, in: pieces)

        if moves.isEmpty {
            return maximizing ? -90000 : 90000
        }

        if maximizing {
            var maxEval = Int.min
            var a = alpha
            for (from, to) in moves {
                var newPieces = pieces
                let captured = applyMove(from: from, to: to, in: &newPieces)
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

    private func positionValue(_ piece: Piece) -> Int {
        let row = piece.position.row
        let col = piece.position.col

        switch piece.type {
        case .pawn:
            let crossed = piece.color == .red ? (row <= 4) : (row >= 5)
            if crossed {
                let advanceBonus = piece.color == .red ? (4 - row) * 15 : (row - 5) * 15
                let centerBonus = (4 - abs(col - 4)) * 5
                return 100 + advanceBonus + centerBonus
            }
            return 0

        case .horse:
            let centerBonus = (4 - abs(col - 4)) * 10 + (4 - abs(row - 4)) * 5
            return centerBonus

        case .chariot:
            let centerBonus = (4 - abs(col - 4)) * 5
            return centerBonus

        case .cannon:
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

    // MARK: - 走子规则

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
