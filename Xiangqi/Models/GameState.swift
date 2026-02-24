import SwiftUI

/// 管理棋局状态：棋子、选中、走子、规则校验、AI 对弈与复盘
class GameState: ObservableObject {
    // MARK: - 通用状态
    @Published var pieces: [Piece] = []
    @Published var selectedPieceId: UUID? = nil
    @Published var currentTurn: PieceColor = .red
    @Published var isCheck: Bool = false
    @Published var isGameOver: Bool = false
    @Published var winner: PieceColor? = nil
    @Published var lastMoveFrom: Position? = nil
    @Published var lastMoveTo: Position? = nil
    @Published var isBoardFlipped: Bool = false

    // MARK: - 对弈模式状态
    @Published var moveHistory: [Move] = []
    @Published var aiEnabled: Bool = true
    @Published var aiColor: PieceColor = .black
    @Published var aiDifficulty: AIEngine.Difficulty = .medium
    @Published var isAIThinking: Bool = false
    private var aiEngine = AIEngine(difficulty: .medium)

    struct Move {
        let piece: Piece
        let from: Position
        let to: Position
        let captured: Piece?
    }

    // MARK: - 分析回调
    var analyzeCallback: ((_ piecesBefore: [Piece], _ piecesAfter: [Piece],
                           _ movingPiece: Piece, _ from: Position, _ to: Position,
                           _ captured: Piece?, _ moveColor: PieceColor, _ moveIndex: Int) -> Void)?
    var aiMoveCallback: ((_ piecesAfter: [Piece]) -> Void)?

    // MARK: - 复盘状态
    @Published var isInReview: Bool = false
    @Published var reviewIndex: Int = 0
    private var reviewInitialPieces: [Piece] = []
    private var reviewSavedPieces: [Piece] = []
    private var reviewSavedTurn: PieceColor = .red

    /// 当前选中棋子的合法走法（对弈模式）
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
        pieces = Self.standardPieces()
        moveHistory.removeAll()
        selectedPieceId = nil
        currentTurn = .red
        isCheck = false
        isGameOver = false
        winner = nil
        lastMoveFrom = nil
        lastMoveTo = nil
        isAIThinking = false
    }

    func startNewGame() {
        setupInitialPosition()
        AIEngine.resetForNewGame()
        if aiEnabled && currentTurn == aiColor {
            triggerAIMove()
        }
    }

    static func standardPieces() -> [Piece] {
        var pieces: [Piece] = []
        let backRow: [(PieceType, Int)] = [
            (.chariot, 0), (.horse, 1), (.elephant, 2), (.advisor, 3),
            (.king, 4), (.advisor, 5), (.elephant, 6), (.horse, 7), (.chariot, 8)
        ]
        for (type, col) in backRow {
            pieces.append(Piece(type: type, color: .black, position: Position(row: 0, col: col)))
        }
        pieces.append(Piece(type: .cannon, color: .black, position: Position(row: 2, col: 1)))
        pieces.append(Piece(type: .cannon, color: .black, position: Position(row: 2, col: 7)))
        for col in stride(from: 0, through: 8, by: 2) {
            pieces.append(Piece(type: .pawn, color: .black, position: Position(row: 3, col: col)))
        }
        for (type, col) in backRow {
            pieces.append(Piece(type: type, color: .red, position: Position(row: 9, col: col)))
        }
        pieces.append(Piece(type: .cannon, color: .red, position: Position(row: 7, col: 1)))
        pieces.append(Piece(type: .cannon, color: .red, position: Position(row: 7, col: 7)))
        for col in stride(from: 0, through: 8, by: 2) {
            pieces.append(Piece(type: .pawn, color: .red, position: Position(row: 6, col: col)))
        }
        return pieces
    }

    // MARK: - 对弈交互

    func piece(at position: Position) -> Piece? {
        pieces.first { $0.position == position }
    }

    func selectOrMove(at position: Position) {
        guard !isGameOver, !isAIThinking, !isInReview else { return }
        // AI 回合时不允许人类操作
        if aiEnabled && currentTurn == aiColor { return }
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
        let piecesBefore = pieces
        let moveColor = currentTurn
        let moveIndex = moveHistory.count

        if let captured = captured {
            pieces.removeAll { $0.id == captured.id }
        }
        if let newIndex = pieces.firstIndex(where: { $0.id == selectedId }) {
            pieces[newIndex].position = position
        }

        moveHistory.append(Move(piece: movingPiece, from: from, to: position, captured: captured))
        currentTurn = (currentTurn == .red) ? .black : .red
        selectedPieceId = nil
        lastMoveFrom = from
        lastMoveTo = position

        let piecesAfter = pieces

        if let captured = captured, captured.type == .king {
            isGameOver = true
            winner = movingPiece.color
            isCheck = false
        } else {
            isCheck = isInCheck(currentTurn)
            // 如果轮到 AI，触发 AI 走棋
            if aiEnabled && currentTurn == aiColor && !isGameOver {
                triggerAIMove()
            }
        }

        // 分析回调（人类走子 & AI 走子都会触发）
        analyzeCallback?(piecesBefore, piecesAfter, movingPiece, from, position, captured, moveColor, moveIndex)
    }

    // MARK: - AI 对弈

    func setAIDifficulty(_ difficulty: AIEngine.Difficulty) {
        aiDifficulty = difficulty
        aiEngine = AIEngine(difficulty: difficulty)
    }

    func setAIColor(_ color: PieceColor) {
        aiColor = color
        if aiEnabled && currentTurn == aiColor && !isGameOver && !isAIThinking {
            triggerAIMove()
        }
    }

    func toggleAI() {
        aiEnabled.toggle()
        if aiEnabled && currentTurn == aiColor && !isGameOver {
            triggerAIMove()
        }
    }

    private func triggerAIMove() {
        guard !isAIThinking else { return }
        isAIThinking = true
        let currentPieces = pieces
        let color = aiColor
        let engine = aiEngine

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = engine.bestMove(pieces: currentPieces, for: color)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard let self = self, self.aiEnabled, !self.isGameOver else {
                    self?.isAIThinking = false
                    return
                }
                self.isAIThinking = false
                if let move = result {
                    // 选中并执行 AI 走法
                    if let piece = self.pieces.first(where: { $0.position == move.from && $0.color == color }) {
                        self.selectedPieceId = piece.id
                        self.performMove(to: move.to)
                        self.aiMoveCallback?(self.pieces)
                    }
                }
            }
        }
    }

    func undoMove() {
        guard !isAIThinking, !isInReview else { return }

        // AI 模式下悔棋需要撤回两步（AI 的走法 + 人的走法）
        let stepsToUndo = (aiEnabled && moveHistory.count >= 2) ? 2 : 1

        for _ in 0..<stepsToUndo {
            guard let lastMove = moveHistory.popLast() else { break }
            if let idx = pieces.firstIndex(where: { $0.id == lastMove.piece.id }) {
                pieces[idx].position = lastMove.from
            }
            if let captured = lastMove.captured {
                pieces.append(captured)
            }
            currentTurn = (currentTurn == .red) ? .black : .red
        }

        selectedPieceId = nil
        isGameOver = false
        winner = nil
        isCheck = isInCheck(currentTurn)

        // 恢复上一步的高亮
        if let prev = moveHistory.last {
            lastMoveFrom = prev.from
            lastMoveTo = prev.to
        } else {
            lastMoveFrom = nil
            lastMoveTo = nil
        }
    }

    /// 回退到指定走法（包含该步），用于从走法记录快速回到当时局面
    func rollbackToMove(_ index: Int) {
        guard !isAIThinking, !isInReview, !moveHistory.isEmpty else { return }
        let target = max(0, min(index, moveHistory.count - 1))
        let retainedMoves = Array(moveHistory.prefix(target + 1))

        pieces = Self.standardPieces()
        currentTurn = .red
        selectedPieceId = nil
        isGameOver = false
        winner = nil
        isCheck = false
        lastMoveFrom = nil
        lastMoveTo = nil

        var rebuiltHistory: [Move] = []
        for oldMove in retainedMoves {
            guard let movingIdx = pieces.firstIndex(where: { $0.position == oldMove.from }) else { continue }

            let movingPiece = pieces[movingIdx]
            let captured = piece(at: oldMove.to)
            if let captured = captured {
                pieces.removeAll { $0.id == captured.id }
            }
            if let idx = pieces.firstIndex(where: { $0.id == movingPiece.id }) {
                pieces[idx].position = oldMove.to
            }

            rebuiltHistory.append(Move(piece: movingPiece, from: oldMove.from, to: oldMove.to, captured: captured))
            currentTurn = (currentTurn == .red) ? .black : .red
            lastMoveFrom = oldMove.from
            lastMoveTo = oldMove.to

            if let captured = captured, captured.type == .king {
                isGameOver = true
                winner = movingPiece.color
                break
            }
        }

        moveHistory = rebuiltHistory
        isCheck = isGameOver ? false : isInCheck(currentTurn)

        if aiEnabled && currentTurn == aiColor && !isGameOver {
            triggerAIMove()
        }
    }

    // MARK: - 复盘模式

    func startReview() {
        guard isGameOver, !moveHistory.isEmpty else { return }
        isInReview = true
        reviewIndex = 0
        reviewSavedPieces = pieces
        reviewSavedTurn = currentTurn
        reviewInitialPieces = Self.standardPieces()
        reviewGoTo(0)
    }

    func reviewGoTo(_ index: Int) {
        guard isInReview else { return }
        let target = max(0, min(index, moveHistory.count - 1))
        reviewIndex = target

        pieces = reviewInitialPieces
        currentTurn = .red

        for i in 0...target {
            let move = moveHistory[i]
            pieces.removeAll { $0.position == move.to }
            if let idx = pieces.firstIndex(where: { $0.position == move.from }) {
                pieces[idx].position = move.to
            }
            currentTurn = (currentTurn == .red) ? .black : .red
        }

        lastMoveFrom = moveHistory[target].from
        lastMoveTo = moveHistory[target].to
        selectedPieceId = nil
    }

    func reviewNext() {
        guard isInReview, reviewIndex < moveHistory.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            reviewGoTo(reviewIndex + 1)
        }
    }

    func reviewPrevious() {
        guard isInReview, reviewIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            reviewGoTo(reviewIndex - 1)
        }
    }

    func exitReview() {
        isInReview = false
        pieces = reviewSavedPieces
        currentTurn = reviewSavedTurn
        if let last = moveHistory.last {
            lastMoveFrom = last.from
            lastMoveTo = last.to
        }
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
        return raw
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

    private func elephantMoves(for piece: Piece) -> [Position] {
        let directions = [(2, 2), (2, -2), (-2, 2), (-2, -2)]
        var moves: [Position] = []
        for (dr, dc) in directions {
            let pos = Position(row: piece.position.row + dr, col: piece.position.col + dc)
            let eye = Position(row: piece.position.row + dr / 2, col: piece.position.col + dc / 2)
            guard pos.isValid else { continue }
            guard isOnOwnSide(pos, for: piece.color) else { continue }
            guard self.piece(at: eye) == nil else { continue }
            if !isOccupiedByFriend(pos, color: piece.color) {
                moves.append(pos)
            }
        }
        return moves
    }

    private func horseMoves(for piece: Piece) -> [Position] {
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
            guard self.piece(at: block) == nil else { continue }
            if !isOccupiedByFriend(target, color: piece.color) {
                moves.append(target)
            }
        }
        return moves
    }

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

    // MARK: - 将军检测

    func isInCheck(_ color: PieceColor) -> Bool {
        guard let king = pieces.first(where: { $0.type == .king && $0.color == color }) else {
            return false
        }
        let enemyColor: PieceColor = color == .red ? .black : .red
        if isAttacked(king.position, by: enemyColor, in: pieces) { return true }
        if kingsFacing(in: pieces) { return true }
        return false
    }

    private func isAttacked(_ pos: Position, by attackerColor: PieceColor, in boardPieces: [Piece]) -> Bool {
        for p in boardPieces where p.color == attackerColor {
            if canReach(piece: p, target: pos, in: boardPieces) { return true }
        }
        return false
    }

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
