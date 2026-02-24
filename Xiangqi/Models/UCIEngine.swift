import Foundation

/// UCI 搜索结果（单 PV）
struct UCISearchResult {
    let bestMove: String
    let ponderMove: String?
    let score: Int
    let isMate: Bool
    let depth: Int
    let pvMoves: [String]
    let wdl: (win: Int, draw: Int, loss: Int)?
}

/// 多 PV 搜索结果
struct UCIMultiPVResult {
    let lines: [UCIPVLine]
}

/// 单条 PV 线
struct UCIPVLine {
    let multipv: Int
    let score: Int
    let isMate: Bool
    let depth: Int
    let moves: [String]
    let wdl: (win: Int, draw: Int, loss: Int)?
}

/// UCI 引擎错误
enum UCIEngineError: Error {
    case binaryNotFound
    case startupFailed(String)
    case engineNotReady
    case timeout
    case parseError(String)
}

/// 管理 Pikafish 进程的 UCI 协议通信层
class UCIEngine {
    private struct EngineResourceConfig {
        let threads: Int
        let hashMB: Int
    }

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?

    private let serialQueue = DispatchQueue(label: "com.xiangqi.uci-engine", qos: .userInitiated)
    private(set) var isReady = false

    private var lineBuffer: [String] = []
    private let lineLock = NSLock()
    private var lineSignal = DispatchSemaphore(value: 0)

    // MARK: - Lifecycle

    func start(completion: @escaping (Result<Void, UCIEngineError>) -> Void) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }

            guard let binaryURL = self.locateBinary() else {
                DispatchQueue.main.async { completion(.failure(.binaryNotFound)) }
                return
            }

            let process = Process()
            process.executableURL = binaryURL
            process.currentDirectoryURL = binaryURL.deletingLastPathComponent()

            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = FileHandle.nullDevice

            self.process = process
            self.stdinPipe = stdinPipe
            self.stdoutPipe = stdoutPipe

            self.setupOutputReading(stdoutPipe)

            process.terminationHandler = { [weak self] _ in
                self?.isReady = false
            }

            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { completion(.failure(.startupFailed(error.localizedDescription))) }
                return
            }

            // UCI 握手
            self.sendCommand("uci")
            guard self.waitForSentinel("uciok", timeout: 5.0) else {
                DispatchQueue.main.async { completion(.failure(.startupFailed("No uciok"))) }
                return
            }

            let resourceConfig = Self.recommendedResourceConfig()
            self.sendCommand("setoption name Threads value \(resourceConfig.threads)")
            self.sendCommand("setoption name Hash value \(resourceConfig.hashMB)")
            self.sendCommand("setoption name UCI_ShowWDL value true")

            self.sendCommand("isready")
            guard self.waitForSentinel("readyok", timeout: 10.0) else {
                DispatchQueue.main.async { completion(.failure(.startupFailed("No readyok"))) }
                return
            }

            self.isReady = true
            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    func shutdown() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.sendCommand("quit")
            self.process?.waitUntilExit()
            self.process = nil
            self.isReady = false
        }
    }

    deinit {
        if let pipe = stdinPipe, let process = process, process.isRunning {
            if let data = "quit\n".data(using: .utf8) {
                pipe.fileHandleForWriting.write(data)
            }
            process.terminate()
        }
    }

    // MARK: - Configuration

    func setSkillLevel(_ level: Int) {
        serialQueue.async { [weak self] in
            self?.sendCommand("setoption name Skill Level value \(max(0, min(20, level)))")
        }
    }

    func setMultiPV(_ count: Int) {
        serialQueue.async { [weak self] in
            self?.sendCommand("setoption name MultiPV value \(max(1, count))")
        }
    }

    func newGame() {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            self.sendCommand("ucinewgame")
            self.sendCommand("isready")
            _ = self.waitForSentinel("readyok", timeout: 5.0)
        }
    }

    func stop() {
        sendCommand("stop")
    }

    // MARK: - Search (同步，须在后台线程调用)

    func searchBestMoveSync(fen: String, depth: Int? = nil, movetime: Int? = nil) -> UCISearchResult? {
        guard isReady else { return nil }

        var result: UCISearchResult?
        let sem = DispatchSemaphore(value: 0)

        serialQueue.async { [weak self] in
            guard let self = self else { sem.signal(); return }

            self.clearLineBuffer()
            self.sendCommand("position fen \(fen)")

            var goCmd = "go"
            if let depth = depth { goCmd += " depth \(depth)" }
            else if let movetime = movetime { goCmd += " movetime \(movetime)" }
            else { goCmd += " depth 15" }

            self.sendCommand(goCmd)
            let lines = self.collectUntilBestmove(timeout: 30.0)
            result = self.parseSinglePVResult(lines: lines)
            sem.signal()
        }

        _ = sem.wait(timeout: .now() + .seconds(35))
        return result
    }

    func searchMultiPVSync(fen: String, pvCount: Int, depth: Int? = nil) -> UCIMultiPVResult {
        guard isReady else { return UCIMultiPVResult(lines: []) }

        var result = UCIMultiPVResult(lines: [])
        let sem = DispatchSemaphore(value: 0)

        serialQueue.async { [weak self] in
            guard let self = self else { sem.signal(); return }

            self.sendCommand("setoption name MultiPV value \(pvCount)")
            self.sendCommand("isready")
            _ = self.waitForSentinel("readyok", timeout: 2.0)

            self.clearLineBuffer()
            self.sendCommand("position fen \(fen)")

            var goCmd = "go"
            if let depth = depth { goCmd += " depth \(depth)" }
            else { goCmd += " depth 12" }

            self.sendCommand(goCmd)
            let lines = self.collectUntilBestmove(timeout: 30.0)

            self.sendCommand("setoption name MultiPV value 1")

            result = self.parseMultiPVResult(lines: lines, pvCount: pvCount)
            sem.signal()
        }

        _ = sem.wait(timeout: .now() + .seconds(35))
        return result
    }

    // MARK: - Availability

    static var isAvailable: Bool {
        let binary = locateBinaryStatic()
        return binary != nil
    }

    // MARK: - Private: Binary Location

    private func locateBinary() -> URL? {
        Self.locateBinaryStatic()
    }

    private static func locateBinaryStatic() -> URL? {
        // 1. App bundle Resources
        if let url = Bundle.main.url(forResource: "pikafish", withExtension: nil) {
            return url
        }
        // 2. App bundle Resources (with exe extension)
        if let url = Bundle.main.url(forResource: "pikafish", withExtension: "exe") {
            return url
        }
        return nil
    }

    private static func recommendedResourceConfig() -> EngineResourceConfig {
        let processInfo = ProcessInfo.processInfo
        let activeCores = max(1, processInfo.activeProcessorCount)

        // 给 UI 和系统留出余量，避免把前台交互拖卡。
        let threads: Int
        if activeCores <= 2 {
            threads = activeCores
        } else {
            threads = min(8, activeCores - 1)
        }

        let totalMemoryMB = Int(processInfo.physicalMemory / (1024 * 1024))
        // 使用约 1/16 物理内存作为 Hash，限制在合理范围内。
        let rawHash = max(64, totalMemoryMB / 16)
        let clampedHash = min(1024, rawHash)
        let roundedHash = max(64, (clampedHash / 16) * 16)

        return EngineResourceConfig(threads: max(1, threads), hashMB: roundedHash)
    }

    // MARK: - Private: I/O

    private func sendCommand(_ cmd: String) {
        guard let data = (cmd + "\n").data(using: .utf8) else { return }
        stdinPipe?.fileHandleForWriting.write(data)
    }

    private func setupOutputReading(_ pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var buffer = Data()
            let newline = Data([0x0A])

            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                buffer.append(data)

                while let range = buffer.range(of: newline) {
                    let lineData = buffer[buffer.startIndex..<range.lowerBound]
                    buffer.removeSubrange(buffer.startIndex...range.lowerBound)
                    if let line = String(data: lineData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                        self?.lineLock.lock()
                        self?.lineBuffer.append(line)
                        self?.lineLock.unlock()
                        self?.lineSignal.signal()
                    }
                }
            }
        }
    }

    private func clearLineBuffer() {
        lineLock.lock()
        lineBuffer.removeAll()
        lineLock.unlock()
        // Drain the semaphore
        while lineSignal.wait(timeout: .now()) == .success {}
    }

    private func waitForSentinel(_ sentinel: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { break }
            if lineSignal.wait(timeout: .now() + .milliseconds(100)) == .success {
                lineLock.lock()
                if let idx = lineBuffer.firstIndex(where: { $0.hasPrefix(sentinel) }) {
                    lineBuffer.removeSubrange(0...idx)
                    lineLock.unlock()
                    return true
                }
                lineLock.unlock()
            }
        }
        return false
    }

    private func collectUntilBestmove(timeout: TimeInterval) -> [String] {
        let deadline = Date().addingTimeInterval(timeout)
        var collected: [String] = []

        while Date() < deadline {
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 { break }
            if lineSignal.wait(timeout: .now() + .milliseconds(100)) == .success {
                lineLock.lock()
                let lines = lineBuffer
                lineBuffer.removeAll()
                lineLock.unlock()

                for line in lines {
                    collected.append(line)
                    if line.hasPrefix("bestmove") {
                        return collected
                    }
                }
            }
        }

        // Timeout: force stop
        sendCommand("stop")
        Thread.sleep(forTimeInterval: 0.2)
        lineLock.lock()
        collected.append(contentsOf: lineBuffer)
        lineBuffer.removeAll()
        lineLock.unlock()

        return collected
    }

    // MARK: - Private: Output Parsing

    private func parseSinglePVResult(lines: [String]) -> UCISearchResult? {
        guard let bestmoveLine = lines.last(where: { $0.hasPrefix("bestmove") }) else { return nil }
        let bmParts = bestmoveLine.split(separator: " ").map(String.init)
        guard bmParts.count >= 2 else { return nil }

        let bestMove = bmParts[1]
        let ponderMove: String? = (bmParts.count >= 4 && bmParts[2] == "ponder") ? bmParts[3] : nil

        var score = 0
        var isMate = false
        var depth = 0
        var pvMoves: [String] = []
        var wdl: (Int, Int, Int)? = nil

        for line in lines.reversed() {
            guard line.hasPrefix("info") && line.contains("score") &&
                  !line.contains("upperbound") && !line.contains("lowerbound") else { continue }
            let parts = line.split(separator: " ").map(String.init)

            if let di = parts.firstIndex(of: "depth"), di + 1 < parts.count {
                depth = Int(parts[di + 1]) ?? 0
            }
            if let si = parts.firstIndex(of: "score"), si + 2 < parts.count {
                if parts[si + 1] == "cp" {
                    score = Int(parts[si + 2]) ?? 0
                    isMate = false
                } else if parts[si + 1] == "mate" {
                    let m = Int(parts[si + 2]) ?? 0
                    score = m > 0 ? 100000 - m : -100000 - m
                    isMate = true
                }
            }
            if let wi = parts.firstIndex(of: "wdl"), wi + 3 < parts.count {
                wdl = (Int(parts[wi + 1]) ?? 0, Int(parts[wi + 2]) ?? 0, Int(parts[wi + 3]) ?? 0)
            }
            if let pi = parts.firstIndex(of: "pv"), pi + 1 < parts.count {
                pvMoves = Array(parts[(pi + 1)...])
            }
            break
        }

        return UCISearchResult(bestMove: bestMove, ponderMove: ponderMove,
                               score: score, isMate: isMate, depth: depth,
                               pvMoves: pvMoves, wdl: wdl)
    }

    private func parseMultiPVResult(lines: [String], pvCount: Int) -> UCIMultiPVResult {
        var pvLines: [Int: UCIPVLine] = [:]

        for line in lines {
            guard line.hasPrefix("info") && line.contains("multipv") && line.contains("score") else { continue }
            let parts = line.split(separator: " ").map(String.init)

            guard let mpi = parts.firstIndex(of: "multipv"), mpi + 1 < parts.count,
                  let mpv = Int(parts[mpi + 1]) else { continue }

            var depth = 0
            var score = 0
            var isMate = false
            var moves: [String] = []
            var wdl: (Int, Int, Int)? = nil

            if let di = parts.firstIndex(of: "depth"), di + 1 < parts.count {
                depth = Int(parts[di + 1]) ?? 0
            }
            if let si = parts.firstIndex(of: "score"), si + 2 < parts.count {
                if parts[si + 1] == "cp" {
                    score = Int(parts[si + 2]) ?? 0
                } else if parts[si + 1] == "mate" {
                    let m = Int(parts[si + 2]) ?? 0
                    score = m > 0 ? 100000 - m : -100000 - m
                    isMate = true
                }
            }
            if let wi = parts.firstIndex(of: "wdl"), wi + 3 < parts.count {
                wdl = (Int(parts[wi + 1]) ?? 0, Int(parts[wi + 2]) ?? 0, Int(parts[wi + 3]) ?? 0)
            }
            if let pi = parts.firstIndex(of: "pv"), pi + 1 < parts.count {
                moves = Array(parts[(pi + 1)...])
            }

            if let existing = pvLines[mpv], existing.depth >= depth { continue }
            pvLines[mpv] = UCIPVLine(multipv: mpv, score: score, isMate: isMate,
                                     depth: depth, moves: moves, wdl: wdl)
        }

        let sorted = pvLines.sorted { $0.key < $1.key }.map(\.value)
        return UCIMultiPVResult(lines: sorted)
    }
}
