import Foundation

/// 象棋 AI 引擎：仅使用 Pikafish UCI
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
        guard Self.uciAvailable, let engine = Self.sharedUCIEngine else {
            return nil
        }
        configureSkillLevel(engine)
        let fen = FENParser.generate(pieces: pieces, turn: color)
        if let result = engine.searchBestMoveSync(fen: fen, depth: difficulty.pikaDepth),
           let move = ICCSNotation.parseMove(result.bestMove) {
            return move
        }
        return nil
    }

    func topMoves(pieces: [Piece], for color: PieceColor, count: Int, depth: Int) -> [ScoredMove] {
        guard Self.uciAvailable, let engine = Self.sharedUCIEngine else {
            return []
        }
        let fen = FENParser.generate(pieces: pieces, turn: color)
        let result = engine.searchMultiPVSync(fen: fen, pvCount: count, depth: max(depth, 12))
        return result.lines.compactMap { line -> ScoredMove? in
            guard let firstMove = line.moves.first,
                  let move = ICCSNotation.parseMove(firstMove) else { return nil }
            return ScoredMove(from: move.from, to: move.to, score: line.score)
        }
    }

    func deepEvaluate(pieces: [Piece], for color: PieceColor, depth: Int) -> Int {
        guard Self.uciAvailable, let engine = Self.sharedUCIEngine else {
            return 0
        }
        let fen = FENParser.generate(pieces: pieces, turn: color)
        if let result = engine.searchBestMoveSync(fen: fen, depth: max(depth, 10)) {
            // 引擎分数是走子方视角，转为红方视角
            return color == .red ? result.score : -result.score
        }
        return 0
    }

    private func configureSkillLevel(_ engine: UCIEngine) {
        engine.setSkillLevel(difficulty.skillLevel)
    }
}
