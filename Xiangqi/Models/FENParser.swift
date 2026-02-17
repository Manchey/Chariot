import Foundation

/// Xiangqi FEN 解析与生成
///
/// 格式：rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w
/// 大写 = 红方，小写 = 黑方，数字 = 空格数，/ = 换行，w = 红先，b = 黑先
struct FENParser {

    static let initialFEN = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w"

    /// 从 FEN 字符串解析出棋子和走棋方
    static func parse(_ fen: String) -> (pieces: [Piece], turn: PieceColor)? {
        let parts = fen.split(separator: " ")
        guard !parts.isEmpty else { return nil }

        let rows = parts[0].split(separator: "/")
        guard rows.count == 10 else { return nil }

        var pieces: [Piece] = []
        for (row, rowStr) in rows.enumerated() {
            var col = 0
            for char in rowStr {
                if let num = char.wholeNumberValue {
                    col += num
                } else if let (type, color) = charToPiece(char) {
                    pieces.append(Piece(type: type, color: color, position: Position(row: row, col: col)))
                    col += 1
                }
            }
        }

        let turn: PieceColor = (parts.count > 1 && parts[1] == "b") ? .black : .red
        return (pieces, turn)
    }

    /// 从当前棋盘生成 FEN 字符串
    static func generate(pieces: [Piece], turn: PieceColor) -> String {
        var fen = ""
        for row in 0...9 {
            var empty = 0
            for col in 0...8 {
                if let piece = pieces.first(where: { $0.position == Position(row: row, col: col) }) {
                    if empty > 0 { fen += "\(empty)"; empty = 0 }
                    fen += pieceToChar(piece)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { fen += "\(empty)" }
            if row < 9 { fen += "/" }
        }
        fen += turn == .red ? " w" : " b"
        return fen
    }

    // MARK: - Private

    private static func charToPiece(_ char: Character) -> (PieceType, PieceColor)? {
        switch char {
        case "K": return (.king, .red)
        case "A": return (.advisor, .red)
        case "B": return (.elephant, .red)
        case "N": return (.horse, .red)
        case "R": return (.chariot, .red)
        case "C": return (.cannon, .red)
        case "P": return (.pawn, .red)
        case "k": return (.king, .black)
        case "a": return (.advisor, .black)
        case "b": return (.elephant, .black)
        case "n": return (.horse, .black)
        case "r": return (.chariot, .black)
        case "c": return (.cannon, .black)
        case "p": return (.pawn, .black)
        default:  return nil
        }
    }

    private static func pieceToChar(_ piece: Piece) -> String {
        let c: String
        switch piece.type {
        case .king:     c = "k"
        case .advisor:  c = "a"
        case .elephant: c = "b"
        case .horse:    c = "n"
        case .chariot:  c = "r"
        case .cannon:   c = "c"
        case .pawn:     c = "p"
        }
        return piece.color == .red ? c.uppercased() : c
    }
}
