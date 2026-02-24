import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var analyzer = MoveAnalyzer()
    @State private var showingStartScreen = true
    @State private var setupDifficulty: AIEngine.Difficulty = .medium
    @State private var setupAIColor: PieceColor = .black

    private let cellSize: CGFloat = 58
    private let padding: CGFloat = 36

    var body: some View {
        Group {
            if showingStartScreen {
                startScreen
            } else {
                gameScreen
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup {
                if !showingStartScreen {
                    Button(action: { gameState.isBoardFlipped.toggle() }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .help("翻转棋盘 (F)")
                }
            }
        }
        .onAppear {
            setupAnalyzerCallbacks()
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                return handleKeyEvent(event) ? nil : event
            }
        }
        .onChange(of: gameState.moveHistory.count) { _ in
            SoundManager.playMoveSound()
            analyzer.clearHints()
        }
    }

    private var gameScreen: some View {
        HStack(spacing: 0) {
            // 左侧：棋盘
            GameBoardView(gameState: gameState, cellSize: cellSize, padding: padding,
                          hintMoves: analyzer.hintMoves)

            EvaluationBarView(score: analyzer.evaluationScore)
                .padding(.vertical, padding)

            // 右侧：面板
            VStack(alignment: .leading, spacing: 12) {
                if gameState.isInReview {
                    ReviewPanelView(gameState: gameState, analyzer: analyzer)
                } else {
                    playPanel
                }
            }
            .frame(width: 220)
            .padding()
        }
    }

    private var startScreen: some View {
        VStack(spacing: 20) {
            Text("中国象棋")
                .font(.system(size: 32, weight: .bold, design: .serif))

            Text("开始前设置 AI 对弈参数")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("难度")
                        .font(.headline)
                    Picker("难度", selection: $setupDifficulty) {
                        ForEach(AIEngine.Difficulty.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("AI 执子")
                        .font(.headline)
                    Picker("AI 执子", selection: $setupAIColor) {
                        Text("黑方").tag(PieceColor.black)
                        Text("红方").tag(PieceColor.red)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.08)))
            .frame(width: 340)

            Button("开始对局") {
                startGameFromSetup()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func setupAnalyzerCallbacks() {
        gameState.analyzeCallback = { [weak analyzer] piecesBefore, piecesAfter, movingPiece, from, to, captured, moveColor, moveIndex in
            analyzer?.analyzeMove(
                piecesBefore: piecesBefore,
                piecesAfter: piecesAfter,
                movingPiece: movingPiece,
                from: from,
                to: to,
                captured: captured,
                moveColor: moveColor,
                moveIndex: moveIndex
            )
        }
        gameState.aiMoveCallback = { [weak analyzer] piecesAfter in
            analyzer?.updateEvaluation(pieces: piecesAfter)
        }
    }

    private func startGameFromSetup() {
        analyzer.reset()
        gameState.setAIDifficulty(setupDifficulty)
        gameState.aiColor = setupAIColor
        gameState.startNewGame()
        showingStartScreen = false
    }

    private func returnToStartScreen() {
        setupDifficulty = gameState.aiDifficulty
        setupAIColor = gameState.aiColor
        analyzer.reset()
        gameState.setupInitialPosition()
        showingStartScreen = true
    }

    // MARK: - 对弈面板

    private var playPanel: some View {
        return VStack(alignment: .leading, spacing: 16) {
            Text("中国象棋")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("AI 对弈")
                    .font(.headline)
                Text("难度：\(gameState.aiDifficulty.rawValue)")
                    .font(.subheadline)
                Text("AI 执：\(gameState.aiColor == .red ? "红方" : "黑方")")
                    .font(.subheadline)
            }

            Divider()

            HStack(spacing: 8) {
                Circle()
                    .fill(gameState.currentTurn == .red
                          ? Color(red: 0.80, green: 0.10, blue: 0.10)
                          : Color(red: 0.15, green: 0.15, blue: 0.15))
                    .frame(width: 14, height: 14)
                if gameState.isAIThinking {
                    HStack(spacing: 4) {
                        Text("AI 思考中")
                            .font(.headline)
                        ProgressView()
                            .controlSize(.small)
                    }
                } else {
                    Text(gameState.currentTurn == .red ? "红方走棋" : "黑方走棋")
                        .font(.headline)
                }

                Spacer()

                // 最新走法评分
                if let grade = analyzer.lastMoveGrade {
                    gradeView(grade)
                }
                if analyzer.isAnalyzing {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if gameState.isCheck && !gameState.isGameOver {
                Text("将军！")
                    .font(.title3.bold())
                    .foregroundColor(.red)
            }

            if gameState.isGameOver, let winner = gameState.winner {
                VStack(spacing: 8) {
                    Text(winner == .red ? "红方胜！" : "黑方胜！")
                        .font(.title2.bold())
                        .foregroundColor(winner == .red
                                         ? Color(red: 0.80, green: 0.10, blue: 0.10)
                                         : Color(red: 0.15, green: 0.15, blue: 0.15))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.15)))

                    Button("复盘") {
                        let moves = gameState.moveHistory.map { (piece: $0.piece, from: $0.from, to: $0.to, captured: $0.captured) }
                        analyzer.generateFullReview(moves: moves, initialPieces: GameState.standardPieces())
                        gameState.startReview()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            // 提示按钮
            if !gameState.isGameOver && !gameState.isAIThinking {
                Button("提示") {
                    let playerColor: PieceColor = gameState.aiColor == .red ? .black : .red
                    if gameState.currentTurn == playerColor {
                        analyzer.requestHint(pieces: gameState.pieces, for: playerColor)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(gameState.currentTurn == gameState.aiColor)
            }

            if !analyzer.hintMoves.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("候选着法")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let source = analyzer.hintSource {
                            Text(source == .cloud ? "云库" : "本地")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(Array(analyzer.hintMoves.enumerated()), id: \.offset) { idx, move in
                        HStack(spacing: 6) {
                            Text("\(idx + 1).")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 18, alignment: .trailing)

                            Text(hintMoveDescription(move))
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Text(hintScoreText(move.score))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(hintScoreColor(rank: idx))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue.opacity(0.05)))
                    }
                }
            }

            Text("走法记录")
                .font(.headline)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("")
                                .frame(width: 24)
                            Text("红")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("黑")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        ForEach(movePairs, id: \.turn) { pair in
                            HStack(spacing: 6) {
                                Text("\(pair.turn).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .trailing)

                                moveRecordCell(index: pair.redIndex, move: pair.redMove)
                                moveRecordCell(index: pair.blackIndex, move: pair.blackMove)
                            }
                            .id(pair.turn)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: gameState.moveHistory.count) { _ in
                    if let last = gameState.moveHistory.indices.last {
                        proxy.scrollTo((last / 2) + 1, anchor: .bottom)
                    }
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button("悔棋") {
                    gameState.undoMove()
                }
                .disabled(gameState.moveHistory.isEmpty || gameState.isAIThinking)

                Button("开始页") {
                    returnToStartScreen()
                }
                .disabled(gameState.isAIThinking)
            }
            .buttonStyle(.bordered)
        }
    }

    private func gradeView(_ grade: MoveGrade) -> some View {
        HStack(spacing: 3) {
            Text(grade.symbol)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text(grade.rawValue)
                .font(.system(size: 12))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(gradeBackgroundColor(grade)))
    }

    private func gradeBackgroundColor(_ grade: MoveGrade) -> Color {
        switch grade {
        case .brilliant: return .green
        case .good:      return .blue
        case .dubious:   return .yellow
        case .mistake:   return .orange
        case .blunder:   return .red
        }
    }

    private func gradeTextColor(_ grade: MoveGrade) -> Color {
        switch grade {
        case .brilliant: return .green
        case .good:      return .blue
        case .dubious:   return .orange
        case .mistake:   return .orange
        case .blunder:   return .red
        }
    }

    private func moveDescription(_ move: GameState.Move) -> String {
        let name = move.piece.displayName
        let from = "(\(move.from.col),\(move.from.row))"
        let to = "(\(move.to.col),\(move.to.row))"
        let capture = move.captured != nil ? "吃\(move.captured!.displayName)" : ""
        return "\(name) \(from)\u{2192}\(to) \(capture)"
    }

    private struct MovePair {
        let turn: Int
        let redIndex: Int
        let redMove: GameState.Move
        let blackIndex: Int?
        let blackMove: GameState.Move?
    }

    private var movePairs: [MovePair] {
        let moves = gameState.moveHistory
        var pairs: [MovePair] = []
        var i = 0
        var turn = 1
        while i < moves.count {
            let red = moves[i]
            let blackIndex = (i + 1 < moves.count) ? i + 1 : nil
            let blackMove = (i + 1 < moves.count) ? moves[i + 1] : nil
            pairs.append(MovePair(turn: turn, redIndex: i, redMove: red, blackIndex: blackIndex, blackMove: blackMove))
            i += 2
            turn += 1
        }
        return pairs
    }

    @ViewBuilder
    private func moveRecordCell(index: Int?, move: GameState.Move?) -> some View {
        if let index = index, let move = move {
            HStack(spacing: 4) {
                Text(moveDescription(move))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if index < analyzer.reviewAnalyses.count {
                    Text(analyzer.reviewAnalyses[index].grade.symbol)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(gradeTextColor(analyzer.reviewAnalyses[index].grade))
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.gray.opacity(0.06)))
            .contentShape(Rectangle())
            .onTapGesture {
                gameState.rollbackToMove(index)
                analyzer.truncateToMoveCount(gameState.moveHistory.count)
                analyzer.clearHints()
            }
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.clear)
                .frame(maxWidth: .infinity, minHeight: 28)
        }
    }

    private func hintMoveDescription(_ move: AIEngine.ScoredMove) -> String {
        "(\(move.from.col),\(move.from.row)) \u{2192} (\(move.to.col),\(move.to.row))"
    }

    private func hintScoreText(_ score: Int) -> String {
        String(format: "%+d", score)
    }

    private func hintScoreColor(rank: Int) -> Color {
        switch rank {
        case 0: return .blue
        case 1: return .blue.opacity(0.8)
        default: return .secondary
        }
    }

    // MARK: - 键盘快捷键

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 3:  // F 键 — 翻转棋盘
            if !event.modifierFlags.contains(.command) {
                gameState.isBoardFlipped.toggle()
                return true
            }
        case 6:   // Z 键 — 悔棋（对弈模式）
            if event.modifierFlags.contains(.command) {
                gameState.undoMove()
                return true
            }
        default:
            break
        }
        return false
    }
}

// MARK: - 音效管理

struct SoundManager {
    static func playMoveSound() {
        NSSound(named: "Tink")?.play()
    }
}
