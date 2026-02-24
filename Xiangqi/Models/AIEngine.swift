import Foundation

/// 象棋 AI 引擎：仅使用 Pikafish UCI
class AIEngine {
    private enum CloudBook {
        private static let endpoint = URL(string: "https://www.chessdb.cn/chessdb.php")!
        private static let session: URLSession = {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 1.2
            config.timeoutIntervalForResource = 1.5
            return URLSession(configuration: config)
        }()
        private static let cacheLock = NSLock()
        private static var bestMoveCache: [String: String] = [:]
        private static var hintCache: [String: [ScoredMove]] = [:]

        static func queryBestMove(fen: String) -> String? {
            cacheLock.lock()
            let cached = bestMoveCache[fen]
            cacheLock.unlock()
            if let cached {
                return cached
            }
            guard let body = request(action: "querybest", fen: fen),
                  let move = parseQueryBest(body) else {
                return nil
            }
            cacheLock.lock()
            bestMoveCache[fen] = move
            cacheLock.unlock()
            return move
        }

        static func queryHintMoves(fen: String, limit: Int) -> [ScoredMove] {
            let key = "\(fen)#\(limit)"
            cacheLock.lock()
            let cached = hintCache[key]
            cacheLock.unlock()
            if let cached {
                return cached
            }
            guard let body = request(action: "queryall", fen: fen) else { return [] }
            let moves = parseQueryAll(body: body, limit: limit)
            if !moves.isEmpty {
                cacheLock.lock()
                hintCache[key] = moves
                cacheLock.unlock()
            }
            return moves
        }

        private static func request(action: String, fen: String) -> String? {
            var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
            comps?.queryItems = [
                URLQueryItem(name: "action", value: action),
                URLQueryItem(name: "board", value: fen),
                URLQueryItem(name: "learn", value: "0")
            ]
            guard let url = comps?.url else { return nil }

            let sem = DispatchSemaphore(value: 0)
            var text: String?
            var statusOK = false

            let task = session.dataTask(with: url) { data, response, _ in
                defer { sem.signal() }
                if let http = response as? HTTPURLResponse {
                    statusOK = (200...299).contains(http.statusCode)
                } else {
                    statusOK = true
                }
                guard statusOK, let data = data else { return }
                text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            task.resume()
            _ = sem.wait(timeout: .now() + .milliseconds(1600))
            if text == nil { task.cancel() }
            return text
        }

        private static func parseQueryBest(_ body: String) -> String? {
            let lower = body.lowercased()
            if ["invalid board", "nobestmove", "unknown", "checkmate", "stalemate"].contains(lower) {
                return nil
            }
            for token in body.split(separator: "|").map(String.init) {
                if let move = moveString(in: token) {
                    return move
                }
            }
            return nil
        }

        private static func parseQueryAll(body: String, limit: Int) -> [ScoredMove] {
            let lower = body.lowercased()
            if ["invalid board", "unknown", "checkmate", "stalemate"].contains(lower) {
                return []
            }

            var result: [ScoredMove] = []
            for (idx, entry) in body.split(separator: "|").map(String.init).enumerated() {
                guard let moveString = moveString(in: entry),
                      let move = ICCSNotation.parseMove(moveString) else { continue }

                let score = parseField("score", in: entry).flatMap(Int.init) ?? (1000 - idx * 100)
                result.append(ScoredMove(from: move.from, to: move.to, score: score))
                if result.count >= limit { break }
            }
            return result
        }

        private static func moveString(in entry: String) -> String? {
            for part in entry.split(separator: ",").map(String.init) {
                if let value = part.split(separator: ":", maxSplits: 1).dropFirst().first {
                    let key = String(part.prefix { $0 != ":" }).lowercased()
                    if key == "move" || key == "egtb" || key == "search" {
                        return String(value)
                    }
                }
            }
            return nil
        }

        private static func parseField(_ name: String, in entry: String) -> String? {
            for part in entry.split(separator: ",") {
                let pair = part.split(separator: ":", maxSplits: 1).map(String.init)
                if pair.count == 2, pair[0].lowercased() == name {
                    return pair[1]
                }
            }
            return nil
        }
    }

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
        let fen = FENParser.generate(pieces: pieces, turn: color)
        if let cloudMove = Self.CloudBook.queryBestMove(fen: fen),
           let move = ICCSNotation.parseMove(cloudMove) {
            return move
        }

        guard Self.uciAvailable, let engine = Self.sharedUCIEngine else {
            return nil
        }
        configureSkillLevel(engine)
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

    func cloudHintMoves(pieces: [Piece], for color: PieceColor, count: Int) -> [ScoredMove] {
        let fen = FENParser.generate(pieces: pieces, turn: color)
        return Self.CloudBook.queryHintMoves(fen: fen, limit: count)
    }
}
