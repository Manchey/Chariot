import Foundation

enum PieceColor: Equatable {
    case red, black
}

enum PieceType: Equatable {
    case king       // 帅/将
    case advisor    // 仕/士
    case elephant   // 相/象
    case horse      // 马
    case chariot    // 车
    case cannon     // 炮
    case pawn       // 兵/卒
}

struct Piece: Equatable, Identifiable {
    let id: UUID
    let type: PieceType
    let color: PieceColor
    var position: Position

    init(type: PieceType, color: PieceColor, position: Position) {
        self.id = UUID()
        self.type = type
        self.color = color
        self.position = position
    }

    /// 棋子的中文显示名
    var displayName: String {
        switch (type, color) {
        case (.king, .red):     return "帅"
        case (.king, .black):   return "将"
        case (.advisor, .red):  return "仕"
        case (.advisor, .black): return "士"
        case (.elephant, .red): return "相"
        case (.elephant, .black): return "象"
        case (.horse, .red):    return "马"
        case (.horse, .black):  return "马"
        case (.chariot, .red):  return "车"
        case (.chariot, .black): return "车"
        case (.cannon, .red):   return "炮"
        case (.cannon, .black): return "炮"
        case (.pawn, .red):     return "兵"
        case (.pawn, .black):   return "卒"
        }
    }
}
