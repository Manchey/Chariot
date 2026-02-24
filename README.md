# Chariot

A native macOS Chinese Chess (Xiangqi) application built with SwiftUI, currently focused on AI-vs-human gameplay.

macOS 原生中国象棋应用，基于 SwiftUI 构建，当前阶段聚焦 AI 对弈。

## Features / 功能

- Full Xiangqi rules with piece movement validation / 完整的象棋走子规则
- AI opponent powered by [Pikafish](https://github.com/official-pikafish/Pikafish) only (NNUE, Elo ~3954) / 仅使用 Pikafish 引擎驱动的 AI 对手
- 7 difficulty levels from beginner to master / 7 个难度等级，从入门到特级大师
- AI-only game flow with setup screen (difficulty + AI side) / AI 对弈双页面流程（开始设置页 + 对局页）
- Unlimited hints with ranked arrow suggestions / 无限提示（箭头显示推荐走法强弱）
- AI-assisted learning: move scoring, evaluation bar, post-game review / AI 辅助学习：走法评分、评估条、对局复盘
- Clickable move history with rollback (continue from any earlier move) / 走法记录可点击回退，并从任意历史步继续对局
- Board flip, keyboard shortcuts, move sounds / 棋盘翻转、键盘快捷键、走子音效

Note: Replay/PGN import and endgame puzzle modules were removed from the current product path in the recent AI-only refactor.

说明：近期 AI 对弈收口重构后，棋谱回放/PGN 导入与残局练习模块已从当前产品路径移除。

## Requirements / 环境要求

- macOS 14.0+
- Xcode 15+
- Apple Silicon (arm64)

## Setup / 安装

```bash
git clone <repo-url> && cd xiangqi
./scripts/setup-engine.sh   # build Pikafish & download NNUE weights / 编译 Pikafish 并下载 NNUE 权重
open Xiangqi.xcodeproj       # build and run in Xcode / 在 Xcode 中构建运行
```

The setup script compiles the Pikafish binary for Apple Silicon and downloads NNUE weights (~50MB) into `Xiangqi/Resources/`.

安装脚本会自动编译 Apple Silicon 版 Pikafish 二进制，并下载 NNUE 权重文件（约 50MB）到 `Xiangqi/Resources/`。

Without the engine files, AI gameplay, hints, and engine analysis are unavailable.

没有引擎文件时，AI 对弈、提示与引擎分析功能不可用。

## License / 许可

MIT
