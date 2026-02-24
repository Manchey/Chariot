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

```bash
git clone <repo-url> && cd xiangqi
./scripts/setup-engine.sh   # build Pikafish & download NNUE weights
open Xiangqi.xcodeproj       # build and run in Xcode
```

The setup script will compile the Pikafish binary for Apple Silicon and download the NNUE weights (~50MB) into `Xiangqi/Resources/`.

Without the engine files, the app falls back to the built-in minimax AI (depth 1-3).

## License

MIT
