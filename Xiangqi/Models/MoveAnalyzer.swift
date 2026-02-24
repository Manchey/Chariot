import Foundation

/// 走法评分等级
enum MoveGrade: String {
    case brilliant = "好棋"   // delta 0-10
    case good     = "不错"   // delta 11-80
    case dubious  = "疑问"   // delta 81-200
    case mistake  = "失误"   // delta 201-500
    case blunder  = "败着"   // delta >500

    var symbol: String {
        switch self {
        case .brilliant: return "!!"
        case .good:      return "!"
        case .dubious:   return "?!"
        case .mistake:   return "?"
        case .blunder:   return "??"
        }
    }

    var color: String {
        switch self {
        case .brilliant: return "green"
        case .good:      return "blue"
        case .dubious:   return "yellow"
        case .mistake:   return "orange"
        case .blunder:   return "red"
        }
    }
}

/// 单步走法的分析结果
struct MoveAnalysis {
    let moveIndex: Int
    let piece: Piece
    let from: Position
    let to: Position
    let captured: Piece?
    let grade: MoveGrade
    let bestScore: Int
    let actualScore: Int
    let delta: Int
}

/// AI 辅助学习分析器，独立于 GameState 的 ObservableObject
class MoveAnalyzer: ObservableObject {
    @Published var lastMoveGrade: MoveGrade? = nil
    @Published var evaluationScore: Int = 0
    @Published var hintMoves: [AIEngine.ScoredMove] = []
    @Published var reviewAnalyses: [MoveAnalysis] = []
    @Published var isAnalyzing: Bool = false

    private let engine = AIEngine()

    /// 分析深度（Pikafish）
    private var analysisDepth: Int { 14 }

    /// 评估深度（Pikafish）
    private var evalDepth: Int { 10 }

    /// 分析一步走法：比较最佳分与实际分
    func analyzeMove(
        piecesBefore: [Piece],
        piecesAfter: [Piece],
        movingPiece: Piece,
        from: Position,
        to: Position,
        captured: Piece?,
        moveColor: PieceColor,
        moveIndex: Int
    ) {
        isAnalyzing = true
        let engine = self.engine
        let depth = self.analysisDepth
        let evalDepth = self.evalDepth

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 走子前局面的最佳走法分（走子方视角）
            let topMoves = engine.topMoves(pieces: piecesBefore, for: moveColor, count: 1, depth: depth)
            let bestScore = topMoves.first?.score ?? 0

            // 实际走法的分值：在走子前的局面中模拟这步棋
            var simPieces = piecesBefore
            simPieces.removeAll { $0.position == to }
            if let idx = simPieces.firstIndex(where: { $0.position == from }) {
                simPieces[idx].position = to
            }
            let opponent = moveColor == .red ? PieceColor.black : PieceColor.red
            let opponentScore = engine.topMoves(pieces: simPieces, for: opponent, count: 1, depth: depth - 1)
            let actualScore = -(opponentScore.first?.score ?? 0)

            let delta = max(0, bestScore - actualScore)
            let grade = Self.gradeFromDelta(delta)

            // 走子后的局面评估（红方视角）
            let evalScore = engine.deepEvaluate(pieces: piecesAfter, for: .red, depth: evalDepth)

            let analysis = MoveAnalysis(
                moveIndex: moveIndex,
                piece: movingPiece,
                from: from,
                to: to,
                captured: captured,
                grade: grade,
                bestScore: bestScore,
                actualScore: actualScore,
                delta: delta
            )

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.lastMoveGrade = grade
                self.evaluationScore = evalScore
                self.reviewAnalyses.append(analysis)
                self.isAnalyzing = false
            }
        }
    }

    /// 更新局面评估（AI 走棋后调用）
    func updateEvaluation(pieces: [Piece]) {
        let engine = self.engine
        let evalDepth = self.evalDepth
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let score = engine.deepEvaluate(pieces: pieces, for: .red, depth: evalDepth)
            DispatchQueue.main.async {
                self?.evaluationScore = score
            }
        }
    }

    /// 请求提示走法
    func requestHint(pieces: [Piece], for color: PieceColor) {
        let engine = self.engine
        let depth = self.analysisDepth

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cloudMoves = engine.cloudHintMoves(pieces: pieces, for: color, count: 3)
            let moves = cloudMoves.isEmpty
                ? engine.topMoves(pieces: pieces, for: color, count: 3, depth: depth)
                : cloudMoves
            DispatchQueue.main.async {
                self?.hintMoves = moves
            }
        }
    }

    /// 清除提示
    func clearHints() {
        hintMoves = []
    }

    /// 对局回退后截断已有分析结果，避免与走法记录错位
    func truncateToMoveCount(_ count: Int) {
        reviewAnalyses = Array(reviewAnalyses.prefix(max(0, count)))
        lastMoveGrade = reviewAnalyses.last?.grade
    }

    /// 开始新对局时重置
    func reset() {
        lastMoveGrade = nil
        evaluationScore = 0
        hintMoves = []
        reviewAnalyses = []
        isAnalyzing = false
    }

    /// 生成全局复盘分析（对局结束后一次性分析所有步骤）
    func generateFullReview(moves: [(piece: Piece, from: Position, to: Position, captured: Piece?)],
                            initialPieces: [Piece]) {
        guard reviewAnalyses.count < moves.count else { return }

        isAnalyzing = true
        let engine = self.engine
        let depth = self.analysisDepth

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var currentPieces = initialPieces
            var analyses: [MoveAnalysis] = []
            var moveColor: PieceColor = .red

            for (index, move) in moves.enumerated() {
                // 检查是否已有此步分析
                if let existing = self?.reviewAnalyses.first(where: { $0.moveIndex == index }) {
                    analyses.append(existing)
                } else {
                    let topMoves = engine.topMoves(pieces: currentPieces, for: moveColor, count: 1, depth: depth)
                    let bestScore = topMoves.first?.score ?? 0

                    var simPieces = currentPieces
                    simPieces.removeAll { $0.position == move.to }
                    if let idx = simPieces.firstIndex(where: { $0.position == move.from }) {
                        simPieces[idx].position = move.to
                    }
                    let opponent = moveColor == .red ? PieceColor.black : PieceColor.red
                    let opponentScore = engine.topMoves(pieces: simPieces, for: opponent, count: 1, depth: depth - 1)
                    let actualScore = -(opponentScore.first?.score ?? 0)

                    let delta = max(0, bestScore - actualScore)
                    let grade = Self.gradeFromDelta(delta)

                    analyses.append(MoveAnalysis(
                        moveIndex: index,
                        piece: move.piece,
                        from: move.from,
                        to: move.to,
                        captured: move.captured,
                        grade: grade,
                        bestScore: bestScore,
                        actualScore: actualScore,
                        delta: delta
                    ))
                }

                // 推进局面
                currentPieces.removeAll { $0.position == move.to }
                if let idx = currentPieces.firstIndex(where: { $0.position == move.from }) {
                    currentPieces[idx].position = move.to
                }
                moveColor = moveColor == .red ? .black : .red
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.reviewAnalyses = analyses
                self.isAnalyzing = false
            }
        }
    }

    private static func gradeFromDelta(_ delta: Int) -> MoveGrade {
        // Pikafish 厘兵单位阈值
        switch delta {
        case 0...15:   return .brilliant
        case 16...50:  return .good
        case 51...100: return .dubious
        case 101...300: return .mistake
        default:       return .blunder
        }
    }
}
