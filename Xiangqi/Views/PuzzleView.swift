import SwiftUI

/// 残局练习面板
struct PuzzlePanelView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 当前题目信息
            if let puzzle = gameState.puzzle {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(puzzle.title)
                            .font(.headline)
                        Spacer()
                        Text(puzzle.difficulty.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(difficultyColor(puzzle.difficulty).opacity(0.2))
                            .foregroundColor(difficultyColor(puzzle.difficulty))
                            .cornerRadius(4)
                    }
                    Text(puzzle.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // 题目选择
            Menu {
                ForEach(Array(SamplePuzzles.all.enumerated()), id: \.offset) { index, puzzle in
                    Button {
                        gameState.loadPuzzle(puzzle)
                    } label: {
                        HStack {
                            Text("\(index + 1). \(puzzle.title)")
                            Spacer()
                            Text(puzzle.difficulty.rawValue)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "puzzlepiece")
                    Text("选择题目")
                }
            }

            Divider()

            // 状态显示
            Group {
                switch gameState.puzzleStatus {
                case .playing:
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.blue)
                        Text("请走棋 — 第 \(gameState.puzzleStepIndex + 1)/\(gameState.puzzle?.solution.count ?? 0) 步")
                            .font(.headline)
                    }
                case .wrong:
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("走法不对，请再想想")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                case .solved:
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("恭喜，解题正确！")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }

            // 提示
            if let hint = gameState.puzzle?.hint, gameState.showHint {
                Text(hint)
                    .font(.callout)
                    .foregroundColor(.orange)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.1)))
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 12) {
                Button("提示") {
                    gameState.showHint = true
                }
                .disabled(gameState.showHint || gameState.puzzleStatus == .solved)

                Button("重做") {
                    if let puzzle = gameState.puzzle {
                        gameState.loadPuzzle(puzzle)
                    }
                }

                Button("下一题") {
                    gameState.loadNextPuzzle()
                }
                .disabled(gameState.puzzle == nil)
            }
            .buttonStyle(.bordered)
        }
    }

    private func difficultyColor(_ difficulty: Puzzle.Difficulty) -> Color {
        switch difficulty {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }
}
