import SwiftUI

/// 棋谱回放控制面板
struct ReplayPanelView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 棋谱信息
            if let record = gameState.record {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.headline)
                    HStack {
                        Text("红方: \(record.redPlayer)")
                            .foregroundColor(Color(red: 0.80, green: 0.10, blue: 0.10))
                        Spacer()
                        Text("黑方: \(record.blackPlayer)")
                    }
                    .font(.subheadline)
                    if let result = record.result {
                        Text("结果: \(result)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 棋谱选择
            Menu {
                ForEach(SampleGames.all) { game in
                    Button(game.title) {
                        gameState.loadRecord(game)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "book")
                    Text("选择棋谱")
                }
            }

            Divider()

            // 走法列表
            Text("走法 (\(gameState.replayIndex + 1)/\(gameState.replayMoves.count))")
                .font(.headline)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(movePairs, id: \.turnNum) { pair in
                            HStack(spacing: 0) {
                                Text("\(pair.turnNum).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, alignment: .trailing)

                                // 红方走法
                                Text(pair.redNotation)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 2)
                                    .background(moveBackground(for: pair.redIndex))
                                    .cornerRadius(3)
                                    .onTapGesture { gameState.replayGoTo(pair.redIndex) }

                                // 黑方走法
                                if let blackNotation = pair.blackNotation, let blackIdx = pair.blackIndex {
                                    Text(blackNotation)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 2)
                                        .background(moveBackground(for: blackIdx))
                                        .cornerRadius(3)
                                        .onTapGesture { gameState.replayGoTo(blackIdx) }
                                } else {
                                    Text("")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .font(.system(.body, design: .monospaced))
                            .id(pair.turnNum)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: gameState.replayIndex) { _ in
                    let turnNum = (gameState.replayIndex / 2) + 1
                    proxy.scrollTo(turnNum, anchor: .center)
                }
            }

            // 注释
            if let comment = gameState.currentComment {
                Text(comment)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.yellow.opacity(0.1)))
            }

            Spacer()

            // 回放控制
            HStack(spacing: 8) {
                Spacer()
                Button(action: { gameState.replayFirst() }) {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(gameState.replayIndex < 0)

                Button(action: { gameState.replayPrevious() }) {
                    Image(systemName: "backward.fill")
                }
                .disabled(gameState.replayIndex < 0)

                Button(action: { gameState.toggleAutoPlay() }) {
                    Image(systemName: gameState.isAutoPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(gameState.replayMoves.isEmpty)

                Button(action: { gameState.replayNext() }) {
                    Image(systemName: "forward.fill")
                }
                .disabled(gameState.replayIndex >= gameState.replayMoves.count - 1)

                Button(action: { gameState.replayLast() }) {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(gameState.replayIndex >= gameState.replayMoves.count - 1)
                Spacer()
            }
            .font(.title3)
            .buttonStyle(.borderless)
        }
    }

    // MARK: - 走法配对

    private struct MovePair {
        let turnNum: Int
        let redNotation: String
        let redIndex: Int
        let blackNotation: String?
        let blackIndex: Int?
    }

    private var movePairs: [MovePair] {
        var pairs: [MovePair] = []
        let moves = gameState.replayMoves
        var i = 0
        var turnNum = 1
        while i < moves.count {
            let red = moves[i]
            let black: (notation: String, from: Position, to: Position)? = (i + 1 < moves.count) ? moves[i + 1] : nil
            pairs.append(MovePair(
                turnNum: turnNum,
                redNotation: red.notation,
                redIndex: i,
                blackNotation: black?.notation,
                blackIndex: black != nil ? i + 1 : nil
            ))
            turnNum += 1
            i += 2
        }
        return pairs
    }

    private func moveBackground(for index: Int) -> Color {
        index == gameState.replayIndex ? Color.accentColor.opacity(0.25) : Color.clear
    }
}
