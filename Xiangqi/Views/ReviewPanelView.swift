import SwiftUI

/// 复盘面板：走法列表 + 评分标记 + 导航控制
struct ReviewPanelView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var analyzer: MoveAnalyzer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("复盘分析")
                    .font(.title2.bold())
                Spacer()
                if analyzer.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            // 当前步的详细分析
            if gameState.reviewIndex < analyzer.reviewAnalyses.count {
                let analysis = analyzer.reviewAnalyses[gameState.reviewIndex]
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("第 \(analysis.moveIndex + 1) 步")
                            .font(.headline)
                        gradeTag(analysis.grade)
                    }
                    Text("\(analysis.piece.displayName) (\(analysis.from.col),\(analysis.from.row))\u{2192}(\(analysis.to.col),\(analysis.to.row))")
                        .font(.system(.body, design: .monospaced))
                    if analysis.delta > 0 {
                        Text("分值损失: \(analysis.delta)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)))
            }

            Divider()

            // 走法列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(gameState.moveHistory.enumerated()), id: \.offset) { index, move in
                            HStack(spacing: 4) {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                                Text("\(move.piece.displayName) (\(move.from.col),\(move.from.row))\u{2192}(\(move.to.col),\(move.to.row))")
                                Spacer()
                                if index < analyzer.reviewAnalyses.count {
                                    gradeTag(analyzer.reviewAnalyses[index].grade)
                                }
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(index == gameState.reviewIndex
                                          ? Color.accentColor.opacity(0.15)
                                          : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    gameState.reviewGoTo(index)
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .onChange(of: gameState.reviewIndex) { newIndex in
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }

            Spacer()

            // 导航控制
            HStack(spacing: 12) {
                Button(action: { gameState.reviewGoTo(0) }) {
                    Image(systemName: "backward.end.fill")
                }
                Button(action: { gameState.reviewPrevious() }) {
                    Image(systemName: "chevron.left")
                }
                Text("\(gameState.reviewIndex + 1)/\(gameState.moveHistory.count)")
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 50)
                Button(action: { gameState.reviewNext() }) {
                    Image(systemName: "chevron.right")
                }
                Button(action: { gameState.reviewGoTo(gameState.moveHistory.count - 1) }) {
                    Image(systemName: "forward.end.fill")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("退出复盘") {
                gameState.exitReview()
            }
            .buttonStyle(.bordered)
        }
    }

    private func gradeTag(_ grade: MoveGrade) -> some View {
        Text(grade.symbol)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(gradeColor(grade))
            )
    }

    private func gradeColor(_ grade: MoveGrade) -> Color {
        switch grade {
        case .brilliant: return .green
        case .good:      return .blue
        case .dubious:   return .yellow
        case .mistake:   return .orange
        case .blunder:   return .red
        }
    }
}
