import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var gameState = GameState()

    private let cellSize: CGFloat = 58
    private let padding: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：棋盘
            GameBoardView(gameState: gameState, cellSize: cellSize, padding: padding)

            // 右侧：面板
            VStack(alignment: .leading, spacing: 12) {
                // 模式切换
                Picker("模式", selection: $gameState.mode) {
                    Text("对弈").tag(GameMode.play)
                    Text("棋谱").tag(GameMode.replay)
                    Text("残局").tag(GameMode.puzzle)
                }
                .pickerStyle(.segmented)
                .onChange(of: gameState.mode) { newMode in
                    if newMode == .play {
                        gameState.switchToPlayMode()
                    } else if newMode == .replay {
                        if gameState.record == nil {
                            gameState.loadRecord(SampleGames.all[0])
                        }
                    } else if newMode == .puzzle {
                        if gameState.puzzle == nil {
                            gameState.loadPuzzle(SamplePuzzles.all[0])
                        }
                    }
                }

                // 根据模式显示不同面板
                if gameState.mode == .play {
                    playPanel
                } else if gameState.mode == .replay {
                    ReplayPanelView(gameState: gameState)
                } else {
                    PuzzlePanelView(gameState: gameState)
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

                Button(action: openPGNFile) {
                    Image(systemName: "doc.text")
                }
                .help("导入棋谱 (Cmd+O)")
            }
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                return handleKeyEvent(event) ? nil : event
            }
        }
        .onChange(of: gameState.moveHistory.count) { _ in
            SoundManager.playMoveSound()
        }
        .onChange(of: gameState.replayIndex) { _ in
            if gameState.mode == .replay {
                SoundManager.playMoveSound()
            }
        }
    }

    // MARK: - 对弈面板

    private var playPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("中国象棋")
                .font(.title.bold())

            // AI 设置
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { gameState.aiEnabled },
                    set: { _ in gameState.toggleAI() }
                )) {
                    Text("AI 对弈")
                }

                if gameState.aiEnabled {
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
                        .pickerStyle(.segmented)
                    }

                    HStack(spacing: 8) {
                        Text("AI 执:")
                            .font(.subheadline)
                        Picker("", selection: $gameState.aiColor) {
                            Text("黑方").tag(PieceColor.black)
                            Text("红方").tag(PieceColor.red)
                        }
                        .pickerStyle(.segmented)
                    }
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
            }

            if gameState.isCheck && !gameState.isGameOver {
                Text("将军！")
                    .font(.title3.bold())
                    .foregroundColor(.red)
            }

            if gameState.isGameOver, let winner = gameState.winner {
                Text(winner == .red ? "红方胜！" : "黑方胜！")
                    .font(.title2.bold())
                    .foregroundColor(winner == .red
                                     ? Color(red: 0.80, green: 0.10, blue: 0.10)
                                     : Color(red: 0.15, green: 0.15, blue: 0.15))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.15)))
            }

            Divider()

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
                }
                .disabled(gameState.isAIThinking)
            }
            .buttonStyle(.bordered)
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
        // Cmd+O: 导入棋谱
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "o" {
            openPGNFile()
            return true
        }

        switch event.keyCode {
        case 3:  // F 键 — 翻转棋盘
            if !event.modifierFlags.contains(.command) {
                gameState.isBoardFlipped.toggle()
                return true
            }
        case 123: // 左箭头 — 上一步
            if gameState.mode == .replay {
                gameState.replayPrevious()
                return true
            }
        case 124: // 右箭头 — 下一步
            if gameState.mode == .replay {
                gameState.replayNext()
                return true
            }
        case 115: // Home — 回到开始
            if gameState.mode == .replay {
                gameState.replayFirst()
                return true
            }
        case 119: // End — 跳到最后
            if gameState.mode == .replay {
                gameState.replayLast()
                return true
            }
        case 49:  // 空格 — 自动播放/暂停
            if gameState.mode == .replay {
                gameState.toggleAutoPlay()
                return true
            }
        case 6:   // Z 键 — 悔棋（对弈模式）
            if event.modifierFlags.contains(.command) && gameState.mode == .play {
                gameState.undoMove()
                return true
            }
        default:
            break
        }
        return false
    }

    // MARK: - PGN 文件导入

    private func openPGNFile() {
        let panel = NSOpenPanel()
        panel.title = "选择棋谱文件"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            if let record = PGNParser.parse(content) {
                DispatchQueue.main.async {
                    gameState.loadRecord(record)
                }
            }
        }
    }
}

// MARK: - 音效管理

struct SoundManager {
    static func playMoveSound() {
        NSSound(named: "Tink")?.play()
    }
}
