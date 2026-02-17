import Foundation

/// 中国象棋中文纵线记谱法解析
///
/// 格式：[棋子][纵线][动作][目标]  例如 炮二平五、马8进7
/// 消歧义格式：[前/后/中][棋子][动作][目标]  例如 前车进三
///
/// 纵线编号：
/// - 红方从右到左 一~九（col 8→0）
/// - 黑方从右到左 1~9 （col 0→8，从黑方视角看）
struct ChineseNotation {

    struct ParsedMove {
        let from: Position
        let to: Position
    }

    /// 解析一步中文记谱，返回 (起点, 终点)
    static func parse(_ notation: String, pieces: [Piece], turn: PieceColor) -> ParsedMove? {
        let chars = Array(notation)
        guard chars.count == 4 else { return nil }

        let posHints: Set<Character> = ["前", "后", "後", "中"]
        let isDisambiguation = posHints.contains(chars[0])

        let pieceType: PieceType
        let action: Character
        let targetNum: Int
        var sourcePiece: Piece?

        if isDisambiguation {
            // 前车进三 — chars: [前, 车, 进, 三]
            guard let type = parsePieceType(chars[1]),
                  let tNum = parseNumber(chars[3]) else { return nil }
            pieceType = type
            action = chars[2]
            targetNum = tNum

            // 找到同列且同类型的多个棋子
            let candidates = pieces.filter { $0.type == pieceType && $0.color == turn }
            let grouped = Dictionary(grouping: candidates, by: { $0.position.col })
            // 找到有多个棋子的那列
            guard let multiGroup = grouped.values.first(where: { $0.count >= 2 }) else { return nil }
            let sorted = multiGroup.sorted { $0.position.row < $1.position.row }

            // 红方：前=行号小（靠近顶部=已过河），后=行号大
            // 黑方：前=行号大（靠近底部=已过河），后=行号小
            switch chars[0] {
            case "前":
                sourcePiece = turn == .red ? sorted.first : sorted.last
            case "后", "後":
                sourcePiece = turn == .red ? sorted.last : sorted.first
            case "中":
                if sorted.count >= 3 { sourcePiece = sorted[1] }
            default: break
            }
        } else {
            // 炮二平五 — chars: [炮, 二, 平, 五]
            guard let type = parsePieceType(chars[0]),
                  let srcColNum = parseNumber(chars[1]),
                  let tNum = parseNumber(chars[3]) else { return nil }
            pieceType = type
            action = chars[2]
            targetNum = tNum

            let srcCol = columnToIndex(srcColNum, for: turn)
            let candidates = pieces.filter {
                $0.type == pieceType && $0.color == turn && $0.position.col == srcCol
            }
            sourcePiece = candidates.first
        }

        guard let source = sourcePiece else { return nil }

        // 计算目标位置
        let isDiagonal = [PieceType.horse, .elephant, .advisor].contains(pieceType)

        let dest: Position?
        switch action {
        case "平":
            let destCol = columnToIndex(targetNum, for: turn)
            dest = Position(row: source.position.row, col: destCol)

        case "进", "進":
            if isDiagonal {
                let destCol = columnToIndex(targetNum, for: turn)
                dest = diagonalDest(from: source, toCol: destCol, advancing: true, turn: turn)
            } else {
                let delta = turn == .red ? -targetNum : targetNum
                dest = Position(row: source.position.row + delta, col: source.position.col)
            }

        case "退":
            if isDiagonal {
                let destCol = columnToIndex(targetNum, for: turn)
                dest = diagonalDest(from: source, toCol: destCol, advancing: false, turn: turn)
            } else {
                let delta = turn == .red ? targetNum : -targetNum
                dest = Position(row: source.position.row + delta, col: source.position.col)
            }

        default:
            dest = nil
        }

        guard let destPos = dest, destPos.isValid else { return nil }
        return ParsedMove(from: source.position, to: destPos)
    }

    // MARK: - 坐标转换

    /// 纵线编号 (1-9) → 棋盘列索引 (0-8)
    static func columnToIndex(_ num: Int, for color: PieceColor) -> Int {
        color == .red ? (9 - num) : (num - 1)
    }

    /// 棋盘列索引 (0-8) → 纵线编号 (1-9)
    static func indexToColumn(_ col: Int, for color: PieceColor) -> Int {
        color == .red ? (9 - col) : (col + 1)
    }

    // MARK: - 字符解析

    static func parsePieceType(_ char: Character) -> PieceType? {
        switch char {
        case "帅", "将", "將":       return .king
        case "仕", "士":            return .advisor
        case "相", "象":            return .elephant
        case "马", "馬", "傌":       return .horse
        case "车", "車", "俥":       return .chariot
        case "炮", "砲", "包":       return .cannon
        case "兵", "卒":            return .pawn
        default:                    return nil
        }
    }

    static func parseNumber(_ char: Character) -> Int? {
        let map: [Character: Int] = [
            "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9,
            "１": 1, "２": 2, "３": 3, "４": 4, "５": 5,
            "６": 6, "７": 7, "８": 8, "９": 9,
            "1": 1, "2": 2, "3": 3, "4": 4, "5": 5,
            "6": 6, "7": 7, "8": 8, "9": 9,
        ]
        return map[char]
    }

    // MARK: - Private

    /// 斜线走子（仕/士、相/象、马）的目标坐标计算
    private static func diagonalDest(from piece: Piece, toCol: Int, advancing: Bool, turn: PieceColor) -> Position? {
        let colDiff = abs(toCol - piece.position.col)

        switch piece.type {
        case .advisor:
            guard colDiff == 1 else { return nil }
            let rowDir = advancing ? (turn == .red ? -1 : 1) : (turn == .red ? 1 : -1)
            return Position(row: piece.position.row + rowDir, col: toCol)

        case .elephant:
            guard colDiff == 2 else { return nil }
            let rowDir = advancing ? (turn == .red ? -2 : 2) : (turn == .red ? 2 : -2)
            return Position(row: piece.position.row + rowDir, col: toCol)

        case .horse:
            let rowDiff: Int
            if colDiff == 1 { rowDiff = 2 }
            else if colDiff == 2 { rowDiff = 1 }
            else { return nil }
            let rowDir = advancing ? (turn == .red ? -rowDiff : rowDiff) : (turn == .red ? rowDiff : -rowDiff)
            return Position(row: piece.position.row + rowDir, col: toCol)

        default:
            return nil
        }
    }
}
