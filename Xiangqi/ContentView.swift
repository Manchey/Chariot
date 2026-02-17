import SwiftUI

struct ContentView: View {
    @StateObject private var gameState = GameState()

    /// 根据窗口高度自适应棋盘大小
    private let cellSize: CGFloat = 58
    private let padding: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：棋盘
            GameBoardView(gameState: gameState, cellSize: cellSize, padding: padding)

            // 右侧：信息面板
            VStack(alignment: .leading, spacing: 16) {
                Text("中国象棋")
                    .font(.title.bold())

                // 当前回合
                HStack(spacing: 8) {
                    Circle()
                        .fill(gameState.currentTurn == .red
                              ? Color(red: 0.80, green: 0.10, blue: 0.10)
                              : Color(red: 0.15, green: 0.15, blue: 0.15))
                        .frame(width: 14, height: 14)
                    Text(gameState.currentTurn == .red ? "红方走棋" : "黑方走棋")
                        .font(.headline)
                }

                // 将军提示
                if gameState.isCheck && !gameState.isGameOver {
                    Text("将军！")
                        .font(.title3.bold())
                        .foregroundColor(.red)
                }

                // 胜负结果
                if gameState.isGameOver, let winner = gameState.winner {
                    VStack(spacing: 6) {
                        Text(winner == .red ? "红方胜！" : "黑方胜！")
                            .font(.title2.bold())
                            .foregroundColor(winner == .red
                                             ? Color(red: 0.80, green: 0.10, blue: 0.10)
                                             : Color(red: 0.15, green: 0.15, blue: 0.15))
                        Text(gameState.isCheck ? "绝杀" : "困毙")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.15)))
                }

                Divider()

                // 走法记录
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

                // 操作按钮
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
            .frame(width: 200)
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// 简单描述一步走法
    private func moveDescription(_ move: GameState.Move) -> String {
        let name = move.piece.displayName
        let from = "(\(move.from.col),\(move.from.row))"
        let to = "(\(move.to.col),\(move.to.row))"
        let capture = move.captured != nil ? "吃\(move.captured!.displayName)" : ""
        return "\(name) \(from)→\(to) \(capture)"
    }
}
