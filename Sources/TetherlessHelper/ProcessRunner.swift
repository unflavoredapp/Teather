import Foundation
import Synchronization

struct ProcessResult {
    let status: Int32
    let stdout: String
    let stderr: String
    let stdoutBytes: Data
}
enum ProcessRunnerError: Error, LocalizedError {
    case executableMissing(String)
    case failed(String)
    var errorDescription: String? {
        switch self {
        case .executableMissing(let name): return "Required executable not found: \(name)"
        case .failed(let message): return message
        }
    }
}
enum ProcessRunner {
    static func find(_ executable: String) -> String? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":")
        for path in paths {
            let candidate = String(path) + "/" + executable
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 60, currentDirectory: String? = nil) throws -> ProcessResult {
        guard let path = find(executable) else { throw ProcessRunnerError.executableMissing(executable) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory.map { URL(fileURLWithPath: $0) }
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let group = DispatchGroup()
        let stdoutData = Mutex(Data()), stderrData = Mutex(Data())
        group.enter(); DispatchQueue.global().async { let value = out.fileHandleForReading.readDataToEndOfFile(); stdoutData.withLock { $0 = value }; group.leave() }
        group.enter(); DispatchQueue.global().async { let value = err.fileHandleForReading.readDataToEndOfFile(); stderrData.withLock { $0 = value }; group.leave() }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        if process.isRunning { process.terminate(); throw ProcessRunnerError.failed("Command timed out: \(executable)") }
        group.wait()
        return ProcessResult(status: process.terminationStatus,
                             stdout: String(decoding: stdoutData.withLock { $0 }, as: UTF8.self),
                             stderr: String(decoding: stderrData.withLock { $0 }, as: UTF8.self),
                             stdoutBytes: stdoutData.withLock { $0 })
    }
    static func requireSuccess(_ executable: String, _ arguments: [String], timeout: TimeInterval = 60, currentDirectory: String? = nil) throws -> String {
        let result = try run(executable, arguments, timeout: timeout, currentDirectory: currentDirectory)
        guard result.status == 0 else { throw ProcessRunnerError.failed(result.stderr.isEmpty ? "\(executable) exited \(result.status)" : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return result.stdout
    }
}
