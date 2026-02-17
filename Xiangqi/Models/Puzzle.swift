import Foundation

/// 残局练习的数据模型
struct Puzzle: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var difficulty: Difficulty
    var fen: String                     // 初始局面 FEN
    var playerColor: PieceColor         // 练习方颜色
    var solution: [SolutionStep]        // 正解步骤
    var hint: String?                   // 提示

    enum Difficulty: String, CaseIterable {
        case easy   = "入门"
        case medium = "中等"
        case hard   = "困难"
    }

    /// 一对走法：练习方走 + 对方应着（最后一步可能没有应着）
    struct SolutionStep {
        let playerFrom: Position
        let playerTo: Position
        let opponentFrom: Position?
        let opponentTo: Position?
    }
}

enum PuzzleStatus {
    case playing        // 正在做题
    case wrong          // 走错了
    case solved         // 完成
}

// MARK: - 示例残局

struct SamplePuzzles {

    static let all: [Puzzle] = [puzzle1, puzzle2, puzzle3, puzzle4, puzzle5]

    /// 1. 直捣黄龙 — 一步杀：车吃将
    static let puzzle1 = Puzzle(
        title: "直捣黄龙",
        description: "红先，一步杀。",
        difficulty: .easy,
        fen: "3k5/9/9/9/9/9/9/9/4R4/4K4 w",
        playerColor: .red,
        solution: [
            Puzzle.SolutionStep(
                playerFrom: Position(row: 8, col: 4),
                playerTo: Position(row: 0, col: 4),
                opponentFrom: nil, opponentTo: nil
            )
        ],
        hint: "车可以沿纵线直捣黄龙。"
    )

    /// 2. 隔山打牛 — 一步杀：炮打将
    static let puzzle2 = Puzzle(
        title: "隔山打牛",
        description: "红先，一步杀。利用炮架进行攻击。",
        difficulty: .easy,
        fen: "3k5/4a4/9/9/9/9/9/3RC4/9/4K4 w",
        playerColor: .red,
        solution: [
            Puzzle.SolutionStep(
                playerFrom: Position(row: 7, col: 4),
                playerTo: Position(row: 0, col: 4),
                opponentFrom: nil, opponentTo: nil
            )
        ],
        hint: "炮需要一个炮架才能吃子。"
    )

    /// 3. 马踏将营 — 一步杀：马踏将
    static let puzzle3 = Puzzle(
        title: "马踏将营",
        description: "红先，一步杀。马跳入将营。",
        difficulty: .easy,
        fen: "4k4/9/3N5/9/9/9/9/9/9/4K4 w",
        playerColor: .red,
        solution: [
            Puzzle.SolutionStep(
                playerFrom: Position(row: 2, col: 3),
                playerTo: Position(row: 0, col: 4),
                opponentFrom: nil, opponentTo: nil
            )
        ],
        hint: "马在什么位置可以直接吃到将？"
    )

    /// 4. 双车夹杀 — 三步杀
    static let puzzle4 = Puzzle(
        title: "双车夹杀",
        description: "红先，三步杀。双车配合绝杀。",
        difficulty: .medium,
        fen: "4k4/9/9/9/9/9/9/R8/8R/4K4 w",
        playerColor: .red,
        solution: [
            Puzzle.SolutionStep(
                playerFrom: Position(row: 7, col: 0),
                playerTo: Position(row: 0, col: 0),
                opponentFrom: Position(row: 0, col: 4),
                opponentTo: Position(row: 0, col: 3)
            ),
            Puzzle.SolutionStep(
                playerFrom: Position(row: 8, col: 8),
                playerTo: Position(row: 0, col: 8),
                opponentFrom: Position(row: 0, col: 3),
                opponentTo: Position(row: 0, col: 4)
            ),
            Puzzle.SolutionStep(
                playerFrom: Position(row: 0, col: 8),
                playerTo: Position(row: 0, col: 4),
                opponentFrom: nil, opponentTo: nil
            )
        ],
        hint: "先用一个车将军，逼将移位，再用另一个车配合。"
    )

    /// 5. 弃车杀将 — 两步杀
    static let puzzle5 = Puzzle(
        title: "弃车杀将",
        description: "红先，两步杀。弃车后炮打绝杀。",
        difficulty: .medium,
        fen: "3k5/4a4/9/9/9/9/9/4RC3/9/4K4 w",
        playerColor: .red,
        solution: [
            Puzzle.SolutionStep(
                playerFrom: Position(row: 7, col: 4),
                playerTo: Position(row: 0, col: 4),
                opponentFrom: Position(row: 1, col: 4),
                opponentTo: Position(row: 0, col: 4)
            ),
            Puzzle.SolutionStep(
                playerFrom: Position(row: 7, col: 5),
                playerTo: Position(row: 0, col: 5),
                opponentFrom: nil, opponentTo: nil
            )
        ],
        hint: "弃子是象棋中常见的战术手段。"
    )
}
