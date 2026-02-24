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

            Text("走法记录")
                .font(.headline)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(gameState.moveHistory.enumerated()), id: \.offset) { index, move in
                            let isRedMove = index % 2 == 0
                            HStack(spacing: 4) {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                Text(isRedMove ? "红" : "黑")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(
                                            isRedMove
                                            ? Color(red: 0.80, green: 0.10, blue: 0.10)
                                            : Color(red: 0.15, green: 0.15, blue: 0.15)
                                        )
                                    )
                                Text(moveDescription(move))
                                Spacer()
                                if index < analyzer.reviewAnalyses.count {
                                    Text(analyzer.reviewAnalyses[index].grade.symbol)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(gradeTextColor(analyzer.reviewAnalyses[index].grade))
                                }
                            }
                            .font(.system(.body, design: .monospaced))
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                gameState.rollbackToMove(index)
                                analyzer.truncateToMoveCount(gameState.moveHistory.count)
                                analyzer.clearHints()
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: gameState.moveHistory.count) { _ in
                    if let last = gameState.moveHistory.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
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
