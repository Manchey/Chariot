import Foundation

/// Position ↔ ICCS 坐标转换
/// ICCS 格式: 列 a-i（对应 col 0-8），行 0-9（rank 0 = row 9/红方底线，rank 9 = row 0/黑方底线）
struct ICCSNotation {

    /// Position → ICCS 方格字符串（2 字符，如 "e0"）
    static func squareString(from position: Position) -> String {
        let colChar = Character(UnicodeScalar(Int(Character("a").asciiValue!) + position.col)!)
        let rank = 9 - position.row
        return "\(colChar)\(rank)"
    }

    /// ICCS 方格字符串 → Position
    static func position(from square: String) -> Position? {
        let chars = Array(square)
        guard chars.count == 2,
              let colAscii = chars[0].asciiValue,
              colAscii >= Character("a").asciiValue!,
              colAscii <= Character("i").asciiValue!,
              let rank = chars[1].wholeNumberValue,
              rank >= 0, rank <= 9 else { return nil }
        let col = Int(colAscii) - Int(Character("a").asciiValue!)
        let row = 9 - rank
        return Position(row: row, col: col)
    }

    /// (from, to) → 4 字符 ICCS 走法字符串（如 "b2e2"）
    static func moveString(from: Position, to: Position) -> String {
        squareString(from: from) + squareString(from: to)
    }

    /// 4 字符 ICCS 走法字符串 → (from, to)
    static func parseMove(_ move: String) -> (from: Position, to: Position)? {
        guard move.count >= 4 else { return nil }
        let fromStr = String(move.prefix(2))
        let toStr = String(move.dropFirst(2).prefix(2))
        guard let from = position(from: fromStr),
              let to = position(from: toStr) else { return nil }
        return (from, to)
    }
}
