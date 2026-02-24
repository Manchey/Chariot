# Changelog / 开发日志

## Project Overview / 项目概览

A native macOS Xiangqi app built with SwiftUI, currently focused on AI-vs-human gameplay and lightweight review/hint assistance. Replay and endgame puzzle modules were removed from the active product path in the recent refactor. The app now uses Pikafish only (no minimax fallback at runtime).

macOS 原生中国象棋应用，SwiftUI 构建，当前阶段聚焦 AI 对弈与轻量复盘/提示。近期重构已从主产品路径移除棋谱回放与残局模块。运行时仅使用 Pikafish（不再回退 minimax）。

## Project Structure / 项目结构

```
Xiangqi/
├── XiangqiApp.swift              # App entry, AppDelegate manages engine lifecycle / 应用入口
├── ContentView.swift             # Setup screen + game screen + side panels / 开始页 + 对局页 + 侧边面板
├── Xiangqi.entitlements          # Entitlements (sandbox disabled) / 权限配置（沙盒已禁用）
├── Assets.xcassets/              # Asset catalog / 资源目录
├── Models/
│   ├── Position.swift            # Board coordinate (row: 0-9, col: 0-8) / 棋盘坐标
│   ├── Piece.swift               # Piece model (type, color, position) / 棋子模型
│   ├── GameState.swift           # Game state, AI turns, review navigation / 棋局状态、AI 落子、复盘导航
│   ├── FENParser.swift           # FEN string parsing / FEN 解析/生成
│   ├── AIEngine.swift            # Pikafish-only facade / Pikafish 门面层（仅 UCI）
│   ├── MoveAnalyzer.swift        # Move analyzer (scoring, hints, review) / 走法分析器
│   ├── ICCSNotation.swift        # ICCS coordinate conversion / ICCS 坐标转换
│   └── UCIEngine.swift           # UCI protocol layer (Pikafish process) / UCI 协议通信层
├── Views/
│   ├── BoardView.swift           # Board canvas + piece visuals (filename legacy) / 棋盘画布与棋子样式（文件名历史遗留）
│   ├── PieceView.swift           # Game board composition + overlays (filename legacy) / 棋盘组合与覆盖层（文件名历史遗留）
│   ├── EvaluationBarView.swift   # Position evaluation bar / 局面评估条
│   └── ReviewPanelView.swift     # Post-game review panel / 对局复盘面板
└── Resources/
    ├── pikafish                  # Pikafish binary (arm64)
    └── pikafish.nnue             # NNUE weights / NNUE 神经网络权重
```

---

## Phase 1: Board Rendering & Move Rules / 阶段一：棋盘渲染与走子规则

**Date / 日期**: 2026-02-17

### What was implemented / 实现内容

- **Board rendering / 棋盘绘制**: Canvas draws 9x10 grid, river boundary, palace diagonals / Canvas 绘制 9×10 格线、楚河汉界、九宫斜线
- **Piece rendering / 棋子渲染**: Circular pieces, red/black colors, Chinese character faces / 圆形棋子，红黑双色，汉字棋面
- **Move rules / 走子规则**: Full rules for all 7 piece types / 七种棋子完整规则实现
  - King (将/帅): One step within the palace / 九宫内上下左右各一格
  - Advisor (士/仕): Diagonal within the palace / 九宫内斜走一格
  - Elephant (象/相): Diagonal two squares, cannot cross river, blocking detection / 田字走法，不能过河，塞象眼检测
  - Horse (马): L-shape move, leg-blocking detection / 日字走法，蹩马腿检测
  - Chariot (车): Straight line, any distance / 直线任意格数，遇子停止
  - Cannon (炮): Straight line move, capture by jumping over exactly one piece / 直线移动，隔一子吃子（炮架）
  - Pawn (兵/卒): Forward only before crossing river, lateral movement after / 未过河只能前进，过河后可左右移动
- **Interaction / 交互**: Click to select, highlight valid targets, click to move / 点击选中、合法目标高亮、点击走子

### Key data structures / 关键数据结构

```swift
struct Position { row: Int, col: Int }  // row 0 = black baseline, row 9 = red baseline
struct Piece { id: UUID, type: PieceType, color: PieceColor, position: Position }
```

---

## Phase 1 Addendum: Check Detection / 阶段一补充：将军检测

**Date / 日期**: 2026-02-17

### What was implemented / 实现内容

- **Check detection / 将军检测**: Detect if a move puts the opponent's king in check / 判断当前走子方是否对对方将军
- **Flying General rule / 对面笑规则**: Two kings cannot face each other on the same file without intervening pieces / 两个将/帅不能在同一列上无子阻隔地直接对面
- **Win condition / 胜负判定**: Capturing the king wins (simplified) / 吃掉老将即判胜（简化规则）

---

## Phase 2: Game Record Engine & Replay / 阶段二：棋谱引擎与回放系统

**Date / 日期**: 2026-02-17

### What was implemented / 实现内容

- **Chinese notation parser / 中文纵线记谱法解析** (`ChineseNotation.swift`)
  - Formats: `炮二平五`, `马8进7`, `前车进一`, etc. / 支持多种记谱格式
  - Disambiguation for multiple pieces on the same file (front/back/middle) / 处理同列多子消歧义（前/后/中）
  - Number mapping: red uses Chinese numerals (一~九), black uses Arabic (1~9) / 红方中文数字，黑方阿拉伯数字
- **PGN parser / PGN 棋谱解析** (`GameRecord.swift`)
  - Parses standard PGN tags and move sequences / 解析标准 PGN 格式标签和走法序列
  - Comment extraction / 支持注释提取
- **Replay system / 回放系统** (`GameState.swift`)
  - Step forward/backward, jump to start/end / 逐步前进/后退、跳转首尾
  - Auto-play (1.5s per move) / 自动播放（1.5 秒/步）
  - Animated move transitions / 走法动画过渡
- **Replay panel / 回放面板** (`ReplayControlView.swift`)
  - Move list, navigation buttons, comment display / 棋谱列表、导航按钮、注释显示
  - 3 built-in sample games / 内置 3 盘样例棋谱

---

## Phase 3: Endgame Puzzles / 阶段三：残局练习模块

**Date / 日期**: 2026-02-17

### What was implemented / 实现内容

- **Puzzle model / 残局题目模型** (`Puzzle.swift`)
  - FEN starting position + solution move sequence / FEN 初始局面 + 解题步骤序列
  - 5 built-in classic endgame puzzles / 内置 5 道经典残局
- **Puzzle interaction / 残局交互** (`GameState.swift`)
  - Validates player moves against the solution / 验证玩家走法是否匹配正解
  - Auto-plays opponent response after correct move / 正确后自动执行对方应着
  - States: in progress / correct / incorrect / 状态：进行中 / 正确 / 错误
- **Puzzle panel / 残局面板** (`PuzzleView.swift`)
  - Title, description, hint button, next puzzle / 题目标题与描述、提示按钮、下一题

---

## Phase 4: AI Engine / 阶段四：AI 对弈引擎

**Date / 日期**: 2026-02-17

### What was implemented / 实现内容

- **Minimax + Alpha-Beta pruning / Minimax + Alpha-Beta 剪枝** (`AIEngine.swift`)
  - Search depth 1-3 / 搜索深度 1-3 层
  - Move ordering: captures searched first / 走法排序优化：吃子走法优先搜索
- **Position evaluation function / 局面评估函数**
  - Piece values: King 10000, Chariot 1000, Cannon 500, Horse 450, Elephant/Advisor 200, Pawn 100 / 子力价值
  - Positional bonuses: pawn crossing river, horse centrality, chariot on center file, cannon in rear / 位置加成
- **AI gameplay interaction / AI 对弈交互**
  - Toggle AI, choose AI color / 开关 AI、选择 AI 执红/执黑
  - Background thread search, 0.3s delay / 后台线程搜索，0.3 秒延迟模拟思考
  - Undo retracts both AI and human moves / 悔棋自动撤回 AI 走法 + 人类走法（两步）

---

## Phase 5: UX Improvements / 阶段五：体验优化

**Date / 日期**: 2026-02-17

### What was implemented / 实现内容

- **Board flip / 棋盘翻转**: F key toggles perspective / F 键切换视角
- **Keyboard shortcuts / 键盘快捷键**: Arrow keys for navigation, Home/End to jump, Space for auto-play, Cmd+Z to undo / 左/右箭头导航、Home/End 跳转、空格自动播放、Cmd+Z 悔棋
- **PGN file import / PGN 文件导入**: Cmd+O opens file panel / Cmd+O 打开文件面板导入外部棋谱
- **Move sound / 走子音效**: System Tink sound / 系统 Tink 音效

---

## Phase 6: AI-Assisted Learning + Pikafish Integration / 阶段六：AI 辅助学习系统 + Pikafish 引擎集成

**Date / 日期**: 2026-02-23

The largest update, containing two subsystems: AI-assisted learning features and Pikafish engine integration.

这是最大的一次更新，包含两个子系统：AI 辅助学习功能和 Pikafish 引擎集成。

### 6.1 AI-Assisted Learning / AI 辅助学习功能

#### Real-time Move Scoring / 走法实时评分

Each move is automatically compared against the engine's best move. Grades are assigned based on score difference:

每步棋自动与引擎最佳走法比较，根据分差评定等级：

| Grade / 等级 | Symbol / 符号 | Minimax delta | Pikafish cp delta | Color / 颜色 |
|-------------|--------------|---------------|-------------------|-------------|
| Brilliant / 好棋 | `!!` | 0-10 | 0-15 | Green / 绿色 |
| Good / 不错 | `!`  | 11-80 | 16-50 | Blue / 蓝色 |
| Dubious / 疑问 | `?!` | 81-200 | 51-100 | Yellow / 黄色 |
| Mistake / 失误 | `?`  | 201-500 | 101-300 | Orange / 橙色 |
| Blunder / 败着 | `??` | >500 | >300 | Red / 红色 |

Scoring flow: search best score before move → simulate actual move and search opponent's best (negated) → compute delta → assign grade.

评分流程：搜索走子前局面最佳分 → 模拟实际走法后搜索对手最佳分取负 → 计算分差 → 评级。

#### Evaluation Bar / 局面评估条 (`EvaluationBarView.swift`)

A 24pt vertical bar on the left side of the board. Red at bottom, black at top. Score maps to 0-1 range (`0.5 + score/6000`) with 0.5s animation.

棋盘左侧 24pt 宽竖条，红方在下、黑方在上。分值映射到 0-1 范围，带 0.5 秒动画过渡。

#### Hint System / 提示系统

3 hints per game. Shows top 3 candidate moves with blue numbered circles on origin squares and blue rectangles on target squares. Cleared after the next move.

每局 3 次提示机会。搜索前 3 候选走法，在棋盘上用蓝色编号圆圈标记起点、蓝色矩形标记终点。走子后自动清除。

#### Post-Game Review / 对局复盘 (`ReviewPanelView.swift`)

After the game ends, click "Review" to enter review mode:

终局后点击"复盘"进入复盘模式：

- Analyzes all moves at once (reuses real-time results) / 一次性分析所有走法（复用实时分析结果）
- Move list with grade symbols, click to jump / 走法列表显示评级符号，点击跳转
- First/prev/next/last navigation / 首步/上步/下步/末步导航
- "Exit review" restores end-of-game state / "退出复盘"恢复终局状态

### 6.2 Pikafish Engine Integration / Pikafish 引擎集成

#### Architecture / 架构设计

Facade pattern. `AIEngine` serves as the unified interface:

采用门面模式（Facade Pattern），`AIEngine` 作为门面层：

```
ContentView / MoveAnalyzer / GameState
              │
        ┌─────┴─────┐
        │  AIEngine  │  ← Facade / 门面
        └─────┬─────┘
       ┌──────┴──────┐
  ┌────┴────┐  ┌─────┴─────┐
  │ UCIEngine│  │  Minimax  │
  │(Pikafish)│  │ (fallback)│
  └─────────┘  └───────────┘
```

- Pikafish binary available → start UCI process, delegate all searches / 有二进制 → 委托 Pikafish
- Binary missing or launch failed → fall back to built-in minimax / 无二进制 → 回退 minimax
- Callers are engine-agnostic / 上层调用方无需关心底层实现

#### UCI Protocol / UCI 协议通信 (`UCIEngine.swift`)

**Process management / 进程管理**:
- `Process` + `Pipe` for stdin/stdout
- Serial `DispatchQueue` for UCI command ordering / 串行队列保证命令顺序
- Handshake: `uci` → `uciok` → options → `isready` → `readyok`
- Defaults: Threads=2, Hash=64MB, UCI_ShowWDL=true

**Output parsing / 输出解析**:
- Line-buffered with `NSLock` + `DispatchSemaphore` / 逐行缓冲 + 锁 + 信号量
- Collects `info` lines until `bestmove`, parses score cp/mate, depth, pv, wdl
- Single PV (`searchBestMoveSync`) and multi PV (`searchMultiPVSync`)

**Synchronous wrappers / 同步封装**:
All search methods are synchronous (internal semaphore wait), as callers already run on background threads.

所有搜索方法设计为同步（内部信号量等待），因为调用方已在后台线程。

#### ICCS Coordinate Conversion / ICCS 坐标转换 (`ICCSNotation.swift`)

```
Position(row: 0, col: 0)  ↔  "a9"  (black top-left / 黑方左上角)
Position(row: 9, col: 4)  ↔  "e0"  (red king / 红方将位)
Move: "b2e2" = Position(7,1) → Position(7,4)
```

Mapping: col 0-8 → letters a-i, rank = 9 - row

#### Difficulty Levels / 难度等级

Expanded from 3 to 7 levels / 从 3 级扩展到 7 级：

| Level / 等级 | Display / 显示名 | Skill Level | Pikafish depth / 深度 | Minimax depth / 深度 |
|-------------|-----------------|-------------|----------------------|---------------------|
| beginner | 入门 | 0 | 6 | 1 |
| easy | 新手 | 3 | 8 | 1 |
| medium | 业余 | 8 | 12 | 2 |
| advanced | 棋手 | 12 | 16 | 2 |
| hard | 高手 | 16 | 20 | 3 |
| expert | 大师 | 19 | 24 | 3 |
| master | 特级 | 20 | 28 | 3 |

#### Dynamic Analysis Depth / 分析深度动态化

`MoveAnalyzer` switches automatically based on engine availability:

`MoveAnalyzer` 根据引擎可用性自动切换：

| Scenario / 场景 | Analysis depth / 分析深度 | Eval depth / 评估深度 |
|----------------|------------------------|--------------------|
| Pikafish available / 可用 | 14 | 10 |
| Minimax fallback / 回退 | 4 | 3 |

#### Engine Lifecycle / 引擎生命周期

- **Init / 初始化**: Shared UCI process starts on first `AIEngine` creation (10s timeout) / 首次创建时启动（10 秒超时）
- **New game / 新对局**: `AIEngine.resetForNewGame()` sends `ucinewgame` to clear hash tables / 发送 `ucinewgame` 清除哈希表
- **App exit / 退出**: `AppDelegate.applicationWillTerminate` calls `AIEngine.shutdownEngine()` → sends `quit`

#### Sandbox Disabled / 沙盒禁用

`com.apple.security.app-sandbox` set to `false` in `Xiangqi.entitlements` to allow `Process` to execute the Pikafish binary.

`Xiangqi.entitlements` 中沙盒设为 `false`，以允许 `Process` 执行 Pikafish 二进制。

---

## Phase 7: AI-Only Product Focus & UX Cleanup / 阶段七：聚焦 AI 对弈与界面收口

**Date / 日期**: 2026-02-24

### What changed (current product direction) / 当前产品方向调整

- **AI-only gameplay focus / 聚焦 AI 对弈**
  - Removed replay/puzzle features from the active UI flow and then from code/project references
  - `GameState` simplified to AI play + review navigation
  - Runtime AI path is now **Pikafish only** (minimax code removed)
- **Unlimited hints / 提示无限量**
  - Hint button no longer consumes per-game quota
- **Two-screen flow / 双页面流程**
  - Added setup screen (difficulty, AI side) before entering the board
  - Gameplay screen no longer exposes mutable pre-game options after start

### Interaction improvements / 交互与可读性优化

- **Move history improvements / 走法记录优化**
  - Red/Black moves are visually distinguished
  - Click any move to rollback to that position and continue play (truncates following moves/analyses)
  - Compact layout: two moves per row (Red + Black in one line)
- **Board feedback improvements / 棋盘反馈优化**
  - Last move highlight changed from bright glow to subtle corner markers on both origin/destination
  - Hint moves rendered as arrows instead of source/target blocks
  - Multiple hint arrows now use color intensity/line width to indicate recommendation strength

### Stability fixes / 稳定性修复

- **Pikafish pipe failure handling / Pikafish 管道写失败防崩**
  - Guard command writes when engine process exits
  - Stop waiting early if engine process is gone
  - Prevent app termination from `Broken pipe` / `SIGPIPE` path in UCI writes

### Performance tuning experiment (reverted) / 性能调优尝试（已回滚）

- A dynamic `Threads/Hash` tuning change was tested (`a6e9859`) and then reverted (`693da3c`) due to high CPU usage without clear speedup.
- 当前版本仍使用保守的默认引擎资源配置（固定 `Threads` / `Hash`）。

### Stage commits / 阶段提交记录

- `ca07db7` Use Pikafish only and remove hint limits
- `1b93955` Focus app on AI play only
- `b61bd7e` Add setup screen and move history navigation
- `b7db06c` Refine hints and compact move history UI
- `3f51992` Handle Pikafish pipe failures without crashing
- `a6e9859` Tune Pikafish threads and hash by machine (**reverted by `693da3c`**)

---

## Phase 7 Addendum: Stability & Cloud Book Integration / 阶段七补充：稳定性与云库接入

**Date / 日期**: 2026-02-24

### Stability and regression fixes / 稳定性与回归修复

- **UCI startup regression fix / UCI 启动回归修复**
  - Fixed a regression where startup handshake commands (`setoption`, `isready`) were blocked by an overly strict pipe-write guard, causing AI to stop moving.
- **AI auto-move after state restore / 回退后 AI 自动续走**
  - Unified AI turn triggering checks after `undo`, move-history rollback, and review exit.
  - Prevents cases where the board correctly rolls back but AI does not resume despite it being AI's turn.

### UI refinements / 界面微调

- **Last-move highlight alignment fix / 上一步角框高亮对齐修复**
  - Reworked corner marker drawing to use aligned overlays instead of negative-coordinate paths, fixing visible offset around pieces.
- **Move record table polish / 走法记录表格优化**
  - Red/Black labels moved to a table header row instead of repeating per move.

### Cloud book integration (chessdb.cn) / 云库接入（chessdb.cn）

- **Cloud-first AI move selection / AI 落子云库优先**
  - `AIEngine.bestMove` now tries `chessdb.cn` cloud book (`querybest`) first.
  - On miss/timeout/network failure, it falls back to local Pikafish search automatically.
- **Cloud candidate hints / 云库候选提示**
  - Hint requests now try cloud book candidates (`queryall`) first, then fall back to local Pikafish `topMoves`.
  - Added short request timeout and in-memory cache to avoid blocking repeated positions.
- **Hint candidate list UI / 提示候选列表 UI**
  - Added a visible list of candidate moves and scores under the hint button.
  - Shows source tag (`云库` / `本地`) so users can tell where the suggestions come from.

### Additional stage commits / 补充阶段提交记录

- `748c21d` Sync README with AI-only gameplay focus
- `aa531be` Fix last-move corner highlight alignment
- `ef4162c` Fix UCI startup commands blocked by pipe guard
- `dc3b6ab` Resume AI turn checks after undo and rollback
- `341442a` Prefer chessdb cloud book for AI move and hints
- `93befc9` Show hint candidate list and simplify move record labels

### Rule correctness fixes / 规则正确性修复

- **Must respond to check / 将军后必须应将**
  - Legal move generation now filters out any move that leaves the moving side still in check (including flying-general exposure).
  - 在合法走法阶段过滤“走后己方仍被将军/形成将帅照面”的着法。
- **Checkmate auto-loss / 将死直接判负**
  - After each move, if the side to move is in check and has no legal response, the game ends immediately and the attacker wins.
  - 每步结束后若被将方处于将军状态且无任何合法应着，立即判负。

### Fast testing mode / 快速测试模式

- **AI vs AI quick test button / AI 自对弈快测按钮**
  - Added a start-screen action to launch AI-vs-AI autoplay for rapid regression testing.
  - 双方均由 AI 连续走子，用于快速验证规则与稳定性。
- **Fast move cadence / 快速出子节奏**
  - Reduces AI move delay in fast-test mode for quick progression.
  - 快测模式下缩短 AI 出子延迟。
- **Noise reduction during test runs / 快测时减少干扰**
  - Skips move sound and move-analysis callbacks during fast-test mode to avoid slowing down mass move playback.
  - 快测模式下关闭走子音效与每步分析回调，避免拖慢测试过程。
