import Foundation

struct CLIResult {
    let status: Int32
    let lines: [String]
}

/// Acumula a saída do processo e a entrega linha a linha.
final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var stored = [String]()
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) { self.onLine = onLine }

    var all: [String] { lock.lock(); defer { lock.unlock() }; return stored }

    func feed(_ data: Data) {
        lock.lock()
        buffer.append(data)
        var out = [String]()
        while let i = buffer.firstIndex(where: { $0 == 10 || $0 == 13 }) {
            let line = String(decoding: buffer[buffer.startIndex..<i], as: UTF8.self)
            buffer.removeSubrange(buffer.startIndex...i)
            if !line.trimmingCharacters(in: .whitespaces).isEmpty { out.append(line) }
        }
        stored += out
        lock.unlock()
        out.forEach(onLine)
    }

    func flush() {
        lock.lock()
        let rest = String(decoding: buffer, as: UTF8.self)
        buffer.removeAll()
        let line = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !line.isEmpty { stored.append(line) }
        lock.unlock()
        if !line.isEmpty { onLine(line) }
    }
}

enum CLI {
    /// Prefere o binário embutido no app; senão usa o do Homebrew.
    static var binaryURL: URL? {
        if let url = Bundle.main.url(forResource: "dsmactools", withExtension: nil) { return url }
        for path in ["/opt/homebrew/bin/dsmactools", "/usr/local/bin/dsmactools"]
        where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Executa o dsmactools sem terminal (stdin vazio), o que ativa o modo não interativo.
    static func run(_ args: [String],
                    onLine: @escaping @Sendable (String) -> Void = { _ in }) async -> CLIResult {
        guard let url = binaryURL else {
            return CLIResult(status: 127, lines: ["O binário dsmactools não foi encontrado."])
        }
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = url
            process.arguments = args
            process.standardInput = FileHandle.nullDevice
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            let collector = LineCollector(onLine: onLine)

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { collector.feed(data) }
            }
            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                let rest = pipe.fileHandleForReading.readDataToEndOfFile()
                if !rest.isEmpty { collector.feed(rest) }
                collector.flush()
                continuation.resume(returning: CLIResult(status: proc.terminationStatus,
                                                         lines: collector.all))
            }
            do { try process.run() } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: CLIResult(status: 126,
                                                         lines: [error.localizedDescription]))
            }
        }
    }
}
