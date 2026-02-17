import Foundation

/// 棋盘上的位置，row=0 为顶部（黑方底线），col=0 为最左列
struct Position: Equatable, Hashable {
    let row: Int  // 0-9
    let col: Int  // 0-8

    var isValid: Bool {
        row >= 0 && row <= 9 && col >= 0 && col <= 8
    }
}
