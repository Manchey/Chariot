# 中国象棋 macOS 应用 — 开发日志

## 项目概览

macOS 原生中国象棋应用，SwiftUI 构建，支持人机对弈、棋谱回放、残局练习、AI 辅助学习。集成 Pikafish 引擎（Stockfish 象棋移植版，NNUE 评估，Elo ~3954）。

## 项目结构

```
Xiangqi/
├── XiangqiApp.swift              # 应用入口，AppDelegate 管理引擎生命周期
├── ContentView.swift             # 主界面：棋盘 + 侧边面板
├── Xiangqi.entitlements          # 权限配置（沙盒已禁用）
├── Assets.xcassets/              # 资源目录
├── Models/
│   ├── Position.swift            # 棋盘坐标 (row: 0-9, col: 0-8)
│   ├── Piece.swift               # 棋子模型（类型、颜色、位置）
│   ├── GameState.swift           # 棋局状态管理（对弈、回放、残局、复盘）
│   ├── FENParser.swift           # FEN 棋局字符串解析/生成
│   ├── ChineseNotation.swift     # 中文纵线记谱法解析
│   ├── GameRecord.swift          # 棋谱数据模型 + PGN 解析
│   ├── Puzzle.swift              # 残局题目模型 + 样例库
│   ├── AIEngine.swift            # AI 引擎门面（UCI 委托 + minimax 回退）
│   ├── MoveAnalyzer.swift        # 走法分析器（评分、评估、提示、复盘）
│   ├── ICCSNotation.swift        # ICCS 坐标转换（Position ↔ 4字符走法）
│   └── UCIEngine.swift           # UCI 协议通信层（Pikafish 进程管理）
├── Views/
│   ├── BoardView.swift           # 棋盘 Canvas 绘制
│   ├── PieceView.swift           # 棋子渲染 + 提示标记 + 交互
│   ├── ReplayControlView.swift   # 棋谱回放面板
│   ├── PuzzleView.swift          # 残局练习面板
│   ├── EvaluationBarView.swift   # 局面评估条
│   └── ReviewPanelView.swift     # 对局复盘面板
└── Resources/
    ├── pikafish                  # Pikafish 二进制 (arm64, 749KB)
    └── pikafish.nnue             # NNUE 神经网络权重 (51.2MB)
```

---

## 阶段一：棋盘渲染与走子规则

**日期**: 2026-02-17
**提交**: `ac175e4` feat: 初始化象棋项目 - 棋盘渲染与完整走子规则

### 实现内容

- **棋盘绘制**: Canvas 绘制 9×10 格线、楚河汉界、九宫斜线
- **棋子渲染**: 圆形棋子，红黑双色，汉字棋面
- **走子规则**: 七种棋子完整规则实现
  - 将/帅：九宫内上下左右各一格
  - 士/仕：九宫内斜走一格
  - 象/相：田字走法，不能过河，塞象眼检测
  - 马：日字走法，蹩马腿检测
  - 车：直线任意格数，遇子停止
  - 炮：直线移动，隔一子吃子（炮架）
  - 兵/卒：未过河只能前进，过河后可左右移动
- **交互**: 点击选中、合法目标高亮、点击走子

### 关键数据结构

```swift
struct Position { row: Int, col: Int }  // row 0=黑方底线, row 9=红方底线
struct Piece { id: UUID, type: PieceType, color: PieceColor, position: Position }
```

---

## 阶段一补充：将军检测

**日期**: 2026-02-17
**提交**: `1572747` feat: 添加将军检测、将死/困毙判定与胜负提示
**提交**: `52503e0` refactor: 将军仅提示不限制走法，吃掉老将才判胜负

### 实现内容

- **将军检测**: 判断当前走子方是否对对方将军
- **对面笑规则**: 两个将/帅不能在同一列上无子阻隔地直接对面
- **胜负判定**: 吃掉老将即判胜（简化规则，不做将死/困毙判定）

---

## 阶段二：棋谱引擎与回放系统

**日期**: 2026-02-17
**提交**: `f5def17` feat: 第二阶段 - 棋谱引擎与回放系统

### 实现内容

- **中文纵线记谱法解析** (`ChineseNotation.swift`)
  - 支持格式：`炮二平五`、`马8进7`、`前车进一` 等
  - 处理同列多子消歧义（前/后/中）
  - 数字映射：红方用中文数字（一~九），黑方用阿拉伯数字（1~9）
- **PGN 棋谱解析** (`GameRecord.swift`)
  - 解析标准 PGN 格式标签和走法序列
  - 支持注释提取
- **回放系统** (`GameState.swift` 回放模式)
  - 逐步前进/后退、跳转首尾
  - 自动播放（1.5 秒/步）
  - 走法动画过渡
- **回放面板** (`ReplayControlView.swift`)
  - 棋谱列表、导航按钮、注释显示
  - 内置 3 盘样例棋谱

---

## 阶段三：残局练习模块

**日期**: 2026-02-17
**提交**: `7f77277` feat: 第三阶段 - 残局练习模块与开局库

### 实现内容

- **残局题目模型** (`Puzzle.swift`)
  - FEN 初始局面 + 解题步骤序列（玩家走法 + 对方应着）
  - 内置 5 道经典残局
- **残局交互** (`GameState.swift` 残局模式)
  - 验证玩家走法是否匹配正解
  - 正确后自动执行对方应着
  - 状态：进行中 / 正确 / 错误
- **残局面板** (`PuzzleView.swift`)
  - 题目标题与描述、提示按钮、下一题

---

## 阶段四：AI 对弈引擎

**日期**: 2026-02-17
**提交**: `f8cf656` feat: 第四阶段 - AI 对弈引擎

### 实现内容

- **Minimax + Alpha-Beta 剪枝** (`AIEngine.swift`)
  - 搜索深度 1-3 层
  - 走法排序优化：吃子走法优先搜索
- **局面评估函数**
  - 子力价值：将 10000、车 1000、炮 500、马 450、象/士 200、兵 100
  - 位置加成：兵过河奖励、马居中奖励、车中路奖励、炮后方奖励
- **AI 对弈交互**
  - 开关 AI、选择 AI 执红/执黑
  - 后台线程搜索，0.3 秒延迟模拟思考
  - 悔棋自动撤回 AI 走法 + 人类走法（两步）

---

## 阶段五：体验优化

**日期**: 2026-02-17
**提交**: `b5cc344` feat: 体验优化 - 棋盘翻转、键盘快捷键、PGN导入、走子音效

### 实现内容

- **棋盘翻转**: F 键切换视角
- **键盘快捷键**: 左/右箭头导航、Home/End 跳转、空格自动播放、Cmd+Z 悔棋
- **PGN 文件导入**: Cmd+O 打开文件面板导入外部棋谱
- **走子音效**: 系统 Tink 音效

---

## 阶段六：AI 辅助学习系统 + Pikafish 引擎集成

**日期**: 2026-02-23
**提交**: `d724435` feat: AI 辅助学习系统 + Pikafish 引擎集成

这是最大的一次更新，包含两个子系统：AI 辅助学习功能和 Pikafish 引擎集成。

### 6.1 AI 辅助学习功能

#### 走法实时评分

每步棋自动与引擎最佳走法比较，根据分差评定等级：

| 等级 | 符号 | 分差 (minimax) | 分差 (Pikafish cp) | 颜色 |
|------|------|----------------|-------------------|------|
| 好棋 | `!!` | 0-10 | 0-15 | 绿色 |
| 不错 | `!`  | 11-80 | 16-50 | 蓝色 |
| 疑问 | `?!` | 81-200 | 51-100 | 黄色 |
| 失误 | `?`  | 201-500 | 101-300 | 橙色 |
| 败着 | `??` | >500 | >300 | 红色 |

评分流程：搜索走子前局面最佳分 → 模拟实际走法后搜索对手最佳分取负 → 计算分差 → 评级。

#### 局面评估条 (`EvaluationBarView.swift`)

棋盘左侧 24pt 宽竖条，红方在下、黑方在上。分值映射到 0-1 范围 (`0.5 + score/6000`)，带 0.5 秒动画过渡。

#### 提示系统

每局 3 次提示机会。点击"提示"后调用 `topMoves` 搜索前 3 候选走法，在棋盘上用蓝色编号圆圈标记起点、蓝色矩形标记终点。走子后自动清除提示。

#### 对局复盘 (`ReviewPanelView.swift`)

终局后点击"复盘"进入复盘模式：
- 一次性分析所有走法（已有实时分析结果的直接复用）
- 走法列表显示评级符号，点击跳转到对应局面
- 首步/上步/下步/末步导航按钮
- "退出复盘"恢复终局状态

### 6.2 Pikafish 引擎集成

#### 架构设计

采用门面模式（Facade Pattern），`AIEngine` 作为门面层：

```
ContentView / MoveAnalyzer / GameState
              │
        ┌─────┴─────┐
        │  AIEngine  │  ← 门面：统一接口
        └─────┬─────┘
       ┌──────┴──────┐
  ┌────┴────┐  ┌─────┴─────┐
  │ UCIEngine│  │  Minimax  │
  │(Pikafish)│  │ (内置回退) │
  └─────────┘  └───────────┘
```

- 有 Pikafish 二进制 → 启动 UCI 进程，所有搜索委托给 Pikafish
- 无二进制 / 启动失败 → 回退到内置 minimax 引擎
- 上层调用方无需关心底层实现

#### UCI 协议通信 (`UCIEngine.swift`)

**进程管理**:
- `Process` + `Pipe` 管理 stdin/stdout
- 串行 `DispatchQueue` 保证 UCI 命令顺序
- 启动握手: `uci` → `uciok` → 配置选项 → `isready` → `readyok`
- 默认配置: Threads=2, Hash=64MB, UCI_ShowWDL=true

**输出解析**:
- 逐行缓冲 + `NSLock` + `DispatchSemaphore` 信号通知
- 收集 `info` 行直到 `bestmove`，解析 score cp/mate、depth、pv、wdl
- 支持单 PV (`searchBestMoveSync`) 和多 PV (`searchMultiPVSync`)

**同步封装**:
所有搜索方法设计为同步（内部信号量等待），因为调用方（`AIEngine`、`MoveAnalyzer`）已在后台线程。

#### ICCS 坐标转换 (`ICCSNotation.swift`)

```
Position(row: 0, col: 0)  ↔  "a9"  (黑方左上角)
Position(row: 9, col: 4)  ↔  "e0"  (红方将位)
走法: "b2e2" = Position(7,1) → Position(7,4)
```

映射规则: col 0-8 → 字母 a-i, rank = 9 - row

#### 难度等级扩展

从 3 级扩展到 7 级：

| 等级 | 显示名 | Skill Level | Pikafish 深度 | Minimax 深度 |
|------|--------|-------------|--------------|-------------|
| beginner | 入门 | 0 | 6 | 1 |
| easy | 新手 | 3 | 8 | 1 |
| medium | 业余 | 8 | 12 | 2 |
| advanced | 棋手 | 12 | 16 | 2 |
| hard | 高手 | 16 | 20 | 3 |
| expert | 大师 | 19 | 24 | 3 |
| master | 特级 | 20 | 28 | 3 |

难度选择器从 `.segmented` 改为 `.menu` 样式以适配 7 级。

#### 分析深度动态化

`MoveAnalyzer` 根据引擎可用性自动切换：

| 场景 | 分析深度 | 评估深度 |
|------|---------|---------|
| Pikafish 可用 | 14 | 10 |
| Minimax 回退 | 4 | 3 |

#### 引擎生命周期

- **初始化**: 首次创建 `AIEngine` 实例时启动共享 UCI 进程（10 秒超时）
- **新对局**: `AIEngine.resetForNewGame()` 发送 `ucinewgame` 清除哈希表
- **应用退出**: `AppDelegate.applicationWillTerminate` 调用 `AIEngine.shutdownEngine()` 发送 `quit`

#### Pikafish 编译

```bash
cd /tmp && git clone https://github.com/official-pikafish/Pikafish.git
cd Pikafish/src && make -j build ARCH=apple-silicon COMP=clang
# 产物: pikafish (Mach-O arm64, 749KB)
# NNUE: pikafish.nnue (51.2MB, 从 GitHub Releases 下载)
```

二进制和 NNUE 文件放入 `Xiangqi/Resources/`，通过 Xcode Copy Bundle Resources 打入 app bundle。`UCIEngine.locateBinary()` 从 `Bundle.main` 查找。

#### 沙盒禁用

`Xiangqi.entitlements` 中 `com.apple.security.app-sandbox` 设为 `false`，以允许 `Process` 执行 Pikafish 二进制。

---

## 变更统计

| 提交 | 文件数 | 增/删行数 |
|------|--------|----------|
| `ac175e4` 棋盘与走子规则 | 7 | +833 |
| `1572747` 将军检测 | 2 | +128 |
| `52503e0` 将军规则调整 | 1 | +8 / -22 |
| `f5def17` 棋谱与回放 | 8 | +683 |
| `7f77277` 残局练习 | 5 | +493 |
| `f8cf656` AI 对弈引擎 | 5 | +380 |
| `b5cc344` 体验优化 | 3 | +114 |
| `d724435` AI 学习 + Pikafish | 14 | +1340 / -33 |
| **合计** | | **~3924 行** |
