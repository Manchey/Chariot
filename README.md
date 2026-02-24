# Chariot

A native macOS Chinese Chess (Xiangqi) application built with SwiftUI.

## Features

- Full Xiangqi rules with piece movement validation
- AI opponent powered by [Pikafish](https://github.com/official-pikafish/Pikafish) (NNUE, Elo ~3954), with built-in minimax fallback
- 7 difficulty levels from beginner to master
- Game record replay with PGN import support
- Endgame puzzles
- AI-assisted learning: move scoring, evaluation bar, hint system, post-game review
- Board flip, keyboard shortcuts, move sounds

## Requirements

- macOS 13.0+
- Xcode 15+
- Apple Silicon (arm64) for Pikafish engine

## Setup

1. Clone the repository
2. Download Pikafish engine files into `Xiangqi/Resources/`:
   - `pikafish` — arm64 binary ([build from source](https://github.com/official-pikafish/Pikafish))
   - `pikafish.nnue` — NNUE weights ([download from releases](https://github.com/official-pikafish/Pikafish/releases))
3. Open `Xiangqi.xcodeproj` in Xcode
4. Build and run

Without the engine files, the app falls back to the built-in minimax AI (depth 1-3).

## License

MIT
