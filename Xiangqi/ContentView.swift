import SwiftUI

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
                }
                .pickerStyle(.segmented)
                .onChange(of: gameState.mode) { newMode in
                    if newMode == .play {
                        gameState.switchToPlayMode()
                    } else if gameState.record == nil {
                        // 切到棋谱模式时自动加载第一个示例
                        gameState.loadRecord(SampleGames.all[0])
                    }
                }

                // 根据模式显示不同面板
                if gameState.mode == .play {
                    playPanel
                } else {
                    ReplayPanelView(gameState: gameState)
                }
            }
            .frame(width: 220)
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 对弈面板

    private var playPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("中国象棋")
                .font(.title.bold())

            HStack(spacing: 8) {
                Circle()
                    .fill(gameState.currentTurn == .red
                          ? Color(red: 0.80, green: 0.10, blue: 0.10)
                          : Color(red: 0.15, green: 0.15, blue: 0.15))
                    .frame(width: 14, height: 14)
                Text(gameState.currentTurn == .red ? "红方走棋" : "黑方走棋")
                    .font(.headline)
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
                .disabled(gameState.moveHistory.isEmpty)

                Button("新对局") {
                    gameState.setupInitialPosition()
                }
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
}
