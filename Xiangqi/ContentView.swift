import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var gameState = GameState()
    @StateObject private var analyzer = MoveAnalyzer()

    private let cellSize: CGFloat = 58
    private let padding: CGFloat = 36

    var body: some View {
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
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup {
                Button(action: { gameState.isBoardFlipped.toggle() }) {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .help("翻转棋盘 (F)")
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
            // 走子后清除提示
            analyzer.clearHints()
        }
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

    // MARK: - 对弈面板

    private var playPanel: some View {
        let isConfigLocked = !gameState.moveHistory.isEmpty || gameState.isAIThinking || gameState.isInReview

        return VStack(alignment: .leading, spacing: 16) {
            Text("中国象棋")
                .font(.title.bold())

            // AI 设置
            VStack(alignment: .leading, spacing: 8) {
                Text("AI 对弈")
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("难度:")
                        .font(.subheadline)
                    Picker("", selection: Binding(
                        get: { gameState.aiDifficulty },
                        set: { gameState.setAIDifficulty($0) }
                    )) {
                        ForEach(AIEngine.Difficulty.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isConfigLocked)
                }

                HStack(spacing: 8) {
                    Text("AI 执:")
                        .font(.subheadline)
                    Picker("", selection: Binding(
                        get: { gameState.aiColor },
                        set: { gameState.setAIColor($0) }
                    )) {
                        Text("黑方").tag(PieceColor.black)
                        Text("红方").tag(PieceColor.red)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isConfigLocked)
                }

                if isConfigLocked {
                    Text("棋局开始后配置已锁定，点击“新对局”后可调整。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
                            HStack(spacing: 4) {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                Text(moveDescription(move))
                                Spacer()
                                if index < analyzer.reviewAnalyses.count {
                                    Text(analyzer.reviewAnalyses[index].grade.symbol)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(gradeTextColor(analyzer.reviewAnalyses[index].grade))
                                }
                            }
                            .font(.system(.body, design: .monospaced))
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

                Button("新对局") {
                    gameState.startNewGame()
                    analyzer.reset()
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
