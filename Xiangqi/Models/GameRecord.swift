import Foundation

/// 一局棋谱的数据模型
struct GameRecord: Identifiable {
    let id = UUID()
    var title: String
    var redPlayer: String
    var blackPlayer: String
    var result: String?
    var initialFEN: String?          // nil = 标准开局
    var moveNotations: [String]      // 每步走法的中文记谱
    var comments: [Int: String]      // 步数索引 → 注释（-1 = 开局注释）
}

// MARK: - PGN 文本解析

struct PGNParser {

    /// 解析 PGN 格式的棋谱文本
    ///
    /// 支持格式：
    /// ```
    /// [Event "全国象棋个人赛"]
    /// [Red "许银川"]
    /// [Black "吕钦"]
    /// 1. 炮二平五  马8进7
    /// 2. 马二进三  车9平8
    /// ```
    static func parse(_ pgn: String) -> GameRecord? {
        var title = ""
        var redPlayer = "红方"
        var blackPlayer = "黑方"
        var result: String?
        var initialFEN: String?
        var moves: [String] = []
        var comments: [Int: String] = [:]

        let lines = pgn.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                parseHeader(trimmed, title: &title, redPlayer: &redPlayer,
                            blackPlayer: &blackPlayer, result: &result, initialFEN: &initialFEN)
            } else {
                parseMoves(trimmed, into: &moves, comments: &comments)
            }
        }

        guard !moves.isEmpty else { return nil }

        return GameRecord(
            title: title.isEmpty ? "未命名棋谱" : title,
            redPlayer: redPlayer,
            blackPlayer: blackPlayer,
            result: result,
            initialFEN: initialFEN,
            moveNotations: moves,
            comments: comments
        )
    }

    // MARK: - Private

    private static func parseHeader(_ line: String, title: inout String, redPlayer: inout String,
                                     blackPlayer: inout String, result: inout String?, initialFEN: inout String?) {
        // 格式: [Key "Value"]
        let content = String(line.dropFirst().dropLast())
        guard let spaceIdx = content.firstIndex(of: " ") else { return }

        let key = String(content[..<spaceIdx]).lowercased()
        var value = String(content[spaceIdx...]).trimmingCharacters(in: .whitespaces)
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        switch key {
        case "event", "title":  title = value
        case "red":             redPlayer = value
        case "black":           blackPlayer = value
        case "result":          result = value
        case "fen":             initialFEN = value
        default: break
        }
    }

    private static func parseMoves(_ line: String, into moves: inout [String], comments: inout [Int: String]) {
        var remaining = line

        // 提取行内注释 {注释内容}
        while let openIdx = remaining.firstIndex(of: "{"),
              let closeIdx = remaining.firstIndex(of: "}"), closeIdx > openIdx {
            let comment = String(remaining[remaining.index(after: openIdx)..<closeIdx])
                .trimmingCharacters(in: .whitespaces)
            if !comment.isEmpty {
                comments[moves.count - 1] = comment
            }
            remaining = String(remaining[..<openIdx]) + String(remaining[remaining.index(after: closeIdx)...])
        }

        // 移除步数编号（如 "1." "2．"）
        var cleaned = remaining
        for i in 1...200 {
            cleaned = cleaned.replacingOccurrences(of: "\(i).", with: " ")
            cleaned = cleaned.replacingOccurrences(of: "\(i)．", with: " ")
            cleaned = cleaned.replacingOccurrences(of: "\(i)、", with: " ")
        }

        // 按空白分割，筛选 4 字符的走法
        let tokens = cleaned.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        for token in tokens {
            let t = token.trimmingCharacters(in: .punctuationCharacters)
            if t.count == 4 && ChineseNotation.parsePieceType(Array(t)[0]) != nil {
                moves.append(t)
            }
        }
    }
}

// MARK: - 示例棋谱

struct SampleGames {

    static let all: [GameRecord] = [game1, game2, game3]

    /// 经典中炮对屏风马
    static let game1 = GameRecord(
        title: "中炮对屏风马",
        redPlayer: "红方",
        blackPlayer: "黑方",
        result: nil,
        initialFEN: nil,
        moveNotations: [
            "炮二平五", "马8进7",
            "马二进三", "车9平8",
            "车一平二", "马2进3",
            "兵七进一", "卒7进1",
            "车二进六", "炮8平9",
            "车二平三", "炮9退1",
            "马八进七", "士4进5",
            "炮八平九", "炮9平4",
        ],
        comments: [
            -1: "中炮对屏风马是象棋最经典的开局体系之一。红方以中炮开局，黑方以双马防守。",
            0: "中炮开局，进攻意图明确。",
            1: "马8进7，屏风马防守，经典应着。",
            2: "马二进三，跳正马，配合中炮。",
            3: "黑方出直车，准备巡河或沉底。",
            6: "先挺七兵活马路。",
            8: "车二进六，巡河车，控制要道。",
            9: "黑方平炮兑车，简化局面。",
        ]
    )

    /// 飞相局
    static let game2 = GameRecord(
        title: "飞相局对左中炮",
        redPlayer: "红方",
        blackPlayer: "黑方",
        result: nil,
        initialFEN: nil,
        moveNotations: [
            "相三进五", "炮8平5",
            "马八进七", "马8进7",
            "兵三进一", "车9进1",
            "马二进三", "车9平7",
            "车一平二", "马2进1",
            "炮八平九", "车1平2",
            "车九进一", "炮2进2",
        ],
        comments: [
            -1: "飞相局是一种柔性布局，红方以相开局，后发制人。",
            0: "飞相开局，属于稳健型布局。",
            1: "黑方架中炮，针锋相对。",
            4: "红方先手出车。",
        ]
    )

    /// 顺炮直车对横车
    static let game3 = GameRecord(
        title: "顺炮直车对横车",
        redPlayer: "红方",
        blackPlayer: "黑方",
        result: nil,
        initialFEN: nil,
        moveNotations: [
            "炮二平五", "炮8平5",
            "马二进三", "马8进7",
            "车一平二", "车9进1",
            "车二进六", "车9平4",
            "兵七进一", "马2进3",
            "马八进七", "车1平2",
        ],
        comments: [
            -1: "顺炮布局是双方均以中炮开局的对攻型布局。",
            0: "红方中炮。",
            1: "黑方顺炮，形成顺炮布局。",
            4: "红方出车巡河，抢占要道。",
            5: "黑方横车，准备兑子。",
        ]
    )
}

// MARK: - 开局库

struct OpeningLibrary {

    struct Category: Identifiable {
        let id = UUID()
        let name: String
        let games: [GameRecord]
    }

    static let categories: [Category] = [
        Category(name: "中炮类", games: [
            SampleGames.game1,
            game_57pao,
            SampleGames.game3,
        ]),
        Category(name: "飞相类", games: [
            SampleGames.game2,
        ]),
        Category(name: "仙人指路类", games: [
            game_xrzl,
        ]),
    ]

    /// 五七炮对屏风马
    static let game_57pao = GameRecord(
        title: "五七炮对屏风马",
        redPlayer: "红方",
        blackPlayer: "黑方",
        result: nil,
        initialFEN: nil,
        moveNotations: [
            "炮二平五", "马8进7",
            "马二进三", "车9平8",
            "车一平二", "马2进3",
            "兵七进一", "卒7进1",
            "炮八平七", "炮2平1",
            "马八进九", "炮1进4",
            "车九平八", "象3进5",
        ],
        comments: [
            -1: "五七炮是中炮布局的重要变例。红方双炮分列五路和七路，攻守兼备。",
            0: "中炮开局。",
            1: "屏风马应对。",
            8: "红方走炮八平七，形成五七炮阵型。",
            9: "黑方炮2平1，边炮过河，积极求战。",
        ]
    )

    /// 仙人指路对卒底炮
    static let game_xrzl = GameRecord(
        title: "仙人指路对卒底炮",
        redPlayer: "红方",
        blackPlayer: "黑方",
        result: nil,
        initialFEN: nil,
        moveNotations: [
            "兵七进一", "炮2平3",
            "炮二平五", "象3进5",
            "马二进三", "马8进7",
            "车一平二", "车9进1",
            "车二进六", "士4进5",
            "马八进七", "卒3进1",
        ],
        comments: [
            -1: "仙人指路是红方以兵开局的布局，试探黑方意图后再决定阵型。",
            0: "挺兵七路，仙人指路，含蓄灵活。",
            1: "黑方炮2平3，卒底炮应对，针对红方七路兵。",
            2: "红方见黑方走卒底炮，架中炮对抗。",
            4: "红方出车巡河。",
        ]
    )
}
