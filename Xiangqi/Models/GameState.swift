import SwiftUI

enum GameMode {
    case play
    case replay
    case puzzle
}

/// 管理棋局状态：棋子、选中、走子、规则校验、棋谱回放
class GameState: ObservableObject {
    // MARK: - 通用状态
    @Published var pieces: [Piece] = []
    @Published var selectedPieceId: UUID? = nil
    @Published var currentTurn: PieceColor = .red
    @Published var isCheck: Bool = false
    @Published var isGameOver: Bool = false
    @Published var winner: PieceColor? = nil
    @Published var mode: GameMode = .play
    @Published var lastMoveFrom: Position? = nil
    @Published var lastMoveTo: Position? = nil
    @Published var isBoardFlipped: Bool = false

    // MARK: - 对弈模式状态
    @Published var moveHistory: [Move] = []
    @Published var aiEnabled: Bool = false
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

    // MARK: - 回放模式状态
    @Published var record: GameRecord? = nil
    @Published var replayMoves: [(notation: String, from: Position, to: Position)] = []
    @Published var replayIndex: Int = -1  // -1 = 初始局面
    @Published var isAutoPlaying: Bool = false
    private var autoPlayTimer: Timer?
    private var replayInitialPieces: [Piece] = []
    private var replayInitialTurn: PieceColor = .red

    // MARK: - 残局练习状态
    @Published var puzzle: Puzzle? = nil
    @Published var puzzleStepIndex: Int = 0       // 当前应走第几步
    @Published var puzzleStatus: PuzzleStatus = .playing
    @Published var showHint: Bool = false
    private var puzzleInitialPieces: [Piece] = []

    /// 当前步的注释
    var currentComment: String? {
        guard mode == .replay, let record = record else { return nil }
        return record.comments[replayIndex]
    }

    /// 当前选中棋子的合法走法（对弈模式和残局练习模式）
    var validMoves: [Position] {
        guard mode == .play || mode == .puzzle,
              let id = selectedPieceId,
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

    // MARK: - 模式切换

    func switchToPlayMode() {
        stopAutoPlay()
        mode = .play
        record = nil
        replayMoves = []
        replayIndex = -1
        setupInitialPosition()
    }

    // MARK: - 对弈交互

    func piece(at position: Position) -> Piece? {
        pieces.first { $0.position == position }
    }

    func selectOrMove(at position: Position) {
        if mode == .puzzle {
            puzzleSelectOrMove(at: position)
            return
        }
        guard mode == .play, !isGameOver, !isAIThinking else { return }
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
    }

    // MARK: - AI 对弈

    func setAIDifficulty(_ difficulty: AIEngine.Difficulty) {
        aiDifficulty = difficulty
        aiEngine = AIEngine(difficulty: difficulty)
    }

    func toggleAI() {
        aiEnabled.toggle()
        if aiEnabled && mode == .play && currentTurn == aiColor && !isGameOver {
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
                guard let self = self, self.aiEnabled, self.mode == .play, !self.isGameOver else {
                    self?.isAIThinking = false
                    return
                }
                self.isAIThinking = false
                if let move = result {
                    // 选中并执行 AI 走法
                    if let piece = self.pieces.first(where: { $0.position == move.from && $0.color == color }) {
                        self.selectedPieceId = piece.id
                        self.performMove(to: move.to)
                    }
                }
            }
        }
    }

    func undoMove() {
        guard mode == .play, !isAIThinking else { return }

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

    // MARK: - 棋谱加载与回放

    func loadRecord(_ record: GameRecord) {
        stopAutoPlay()
        self.record = record
        self.mode = .replay

        // 解析初始局面
        if let fen = record.initialFEN, let result = FENParser.parse(fen) {
            replayInitialPieces = result.pieces
            replayInitialTurn = result.turn
        } else {
            replayInitialPieces = Self.standardPieces()
            replayInitialTurn = .red
        }

        // 逐步解析所有走法
        replayMoves = []
        var currentPieces = replayInitialPieces
        var turn = replayInitialTurn

        for notation in record.moveNotations {
            if let parsed = ChineseNotation.parse(notation, pieces: currentPieces, turn: turn) {
                replayMoves.append((notation, parsed.from, parsed.to))
                // 应用走法以便解析下一步
                currentPieces.removeAll { $0.position == parsed.to }
                if let idx = currentPieces.firstIndex(where: { $0.position == parsed.from }) {
                    currentPieces[idx].position = parsed.to
                }
                turn = (turn == .red) ? .black : .red
            } else {
                break  // 解析失败则停止
            }
        }

        // 显示初始局面
        replayGoTo(-1)
    }

    func replayGoTo(_ index: Int) {
        guard mode == .replay else { return }
        stopAutoPlay()
        let target = max(-1, min(index, replayMoves.count - 1))
        replayIndex = target

        // 从初始局面重建到目标步数
        pieces = replayInitialPieces
        currentTurn = replayInitialTurn

        if target >= 0 {
            for i in 0...target {
                let move = replayMoves[i]
                pieces.removeAll { $0.position == move.to }
                if let idx = pieces.firstIndex(where: { $0.position == move.from }) {
                    pieces[idx].position = move.to
                }
                currentTurn = (currentTurn == .red) ? .black : .red
            }
            lastMoveFrom = replayMoves[target].from
            lastMoveTo = replayMoves[target].to
        } else {
            lastMoveFrom = nil
            lastMoveTo = nil
        }

        isCheck = isInCheck(currentTurn)
        selectedPieceId = nil
        isGameOver = false
        winner = nil
    }

    func replayNext() {
        guard mode == .replay, replayIndex < replayMoves.count - 1 else {
            stopAutoPlay()
            return
        }
        replayGoToAnimated(replayIndex + 1)
    }

    func replayPrevious() {
        guard mode == .replay, replayIndex >= 0 else { return }
        replayGoToAnimated(replayIndex - 1)
    }

    func replayFirst() {
        replayGoToAnimated(-1)
    }

    func replayLast() {
        replayGoToAnimated(replayMoves.count - 1)
    }

    private func replayGoToAnimated(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            replayGoTo(index)
        }
    }

    // MARK: 自动播放

    func toggleAutoPlay() {
        if isAutoPlaying {
            stopAutoPlay()
        } else {
            startAutoPlay()
        }
    }

    private func startAutoPlay() {
        guard replayIndex < replayMoves.count - 1 else { return }
        isAutoPlaying = true
        autoPlayTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.replayNext()
            }
        }
    }

    func stopAutoPlay() {
        isAutoPlaying = false
        autoPlayTimer?.invalidate()
        autoPlayTimer = nil
    }

    // MARK: - 残局练习

    func loadPuzzle(_ puzzle: Puzzle) {
        stopAutoPlay()
        self.puzzle = puzzle
        self.mode = .puzzle
        self.puzzleStepIndex = 0
        self.puzzleStatus = .playing
        self.showHint = false
        self.record = nil
        self.replayMoves = []
        self.replayIndex = -1
        self.moveHistory = []

        if let result = FENParser.parse(puzzle.fen) {
            pieces = result.pieces
            currentTurn = result.turn
        } else {
            pieces = Self.standardPieces()
            currentTurn = .red
        }
        puzzleInitialPieces = pieces
        selectedPieceId = nil
        isCheck = false
        isGameOver = false
        winner = nil
        lastMoveFrom = nil
        lastMoveTo = nil
    }

    func loadNextPuzzle() {
        guard let current = puzzle else { return }
        let all = SamplePuzzles.all
        if let idx = all.firstIndex(where: { $0.title == current.title }),
           idx + 1 < all.count {
            loadPuzzle(all[idx + 1])
        } else {
            loadPuzzle(all[0])
        }
    }

    func puzzleSelectOrMove(at position: Position) {
        guard mode == .puzzle, puzzleStatus == .playing else { return }
        let playerColor = puzzle?.playerColor ?? .red

        if let selectedId = selectedPieceId {
            if validMoves.contains(position) {
                // 检查是否符合正解
                guard let puzzle = puzzle, puzzleStepIndex < puzzle.solution.count else { return }
                let step = puzzle.solution[puzzleStepIndex]

                guard let movingPiece = pieces.first(where: { $0.id == selectedId }) else { return }

                if movingPiece.position == step.playerFrom && position == step.playerTo {
                    // 正确走法
                    applyMove(from: step.playerFrom, to: step.playerTo)

                    // 检查是否有对方应着
                    if let oppFrom = step.opponentFrom, let oppTo = step.opponentTo {
                        // 延迟执行对方应着
                        puzzleStepIndex += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                            self?.applyMove(from: oppFrom, to: oppTo)
                            // 检查是否已完成所有步骤
                            if self?.puzzleStepIndex ?? 0 >= (self?.puzzle?.solution.count ?? 0) {
                                self?.puzzleStatus = .solved
                            }
                        }
                    } else {
                        // 没有对方应着，这步完成即为解题成功
                        puzzleStepIndex += 1
                        puzzleStatus = .solved
                    }
                } else {
                    // 走法不对
                    puzzleStatus = .wrong
                    // 1秒后恢复为playing，让用户重试
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard self?.puzzleStatus == .wrong else { return }
                        self?.puzzleStatus = .playing
                    }
                    selectedPieceId = nil
                }
            } else if let tapped = piece(at: position), tapped.color == playerColor {
                selectedPieceId = tapped.id
            } else {
                selectedPieceId = nil
            }
        } else {
            if let tapped = piece(at: position), tapped.color == playerColor {
                selectedPieceId = tapped.id
            }
        }
    }

    /// 在棋盘上执行一步走法（不做规则检查，用于回放和残局）
    private func applyMove(from: Position, to: Position) {
        let captured = piece(at: to)
        if let captured = captured {
            pieces.removeAll { $0.id == captured.id }
        }
        if let idx = pieces.firstIndex(where: { $0.position == from }) {
            pieces[idx].position = to
        }
        currentTurn = (currentTurn == .red) ? .black : .red
        selectedPieceId = nil
        lastMoveFrom = from
        lastMoveTo = to
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
