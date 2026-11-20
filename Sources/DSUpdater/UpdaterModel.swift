import Foundation

struct ControllerInfo: Decodable {
    let path: String
    let pid: Int
    let target: String?
    let version: Int
    let versionHex: String
    let buildDate: String
    let buildTime: String

    var isEdge: Bool { pid == 0x0df2 }
    var name: String { isEdge ? "DualSense Edge" : "DualSense" }
}

enum FirmwareAvailability: Equatable {
    case unknown
    case upToDate
    case available
}

struct FirmwareCheckResult: Equatable {
    let latest: String?
    let availability: FirmwareAvailability
}

enum FirmwareCheckParser {
    static func parse(lines: [String], currentVersion: String) -> FirmwareCheckResult {
        let latest = lines.lazy.compactMap(latestVersion(in:)).first
        let output = lines.joined(separator: "\n").lowercased()

        if output.contains("no newer firmware") || output.contains("up to date") {
            return FirmwareCheckResult(latest: latest, availability: .upToDate)
        }
        if output.contains("update available") || output.contains("newer firmware available") {
            return FirmwareCheckResult(latest: latest, availability: .available)
        }
        if let latest, let current = numericVersion(currentVersion), let newest = numericVersion(latest) {
            if current == newest {
                return FirmwareCheckResult(latest: latest, availability: .upToDate)
            }
            if current < newest {
                return FirmwareCheckResult(latest: latest, availability: .available)
            }
        }
        return FirmwareCheckResult(latest: latest, availability: .unknown)
    }

    static func versionsMatch(_ lhs: String, _ rhs: String) -> Bool {
        if let left = numericVersion(lhs), let right = numericVersion(rhs) {
            return left == right
        }
        return lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }

    private static func latestVersion(in line: String) -> String? {
        guard line.localizedCaseInsensitiveContains("latest"),
              let separator = line.lastIndex(of: ":") else { return nil }

        return line[line.index(after: separator)...]
            .split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .map(String.init)
            .first(where: { numericVersion($0) != nil })
    }

    private static func numericVersion(_ value: String) -> UInt64? {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("0x") {
            return UInt64(token.dropFirst(2), radix: 16)
        }
        return UInt64(token)
    }
}

@MainActor
final class UpdaterModel: ObservableObject {
    static let shared = UpdaterModel()

    enum Phase: Equatable {
        case loading
        case noController(String)
        case ready
        case updating
        case finished(String)
        case failed(String)
    }
    @Published var phase: Phase = .loading
    @Published var info: ControllerInfo?
    @Published var controllerDetails: ControllerDetails?
    @Published var latest: String?
    @Published var availability: FirmwareAvailability = .unknown
    @Published var checkNote: String?
    @Published var progress: Double = 0
    @Published var status = ""
    @Published var log: [String] = []

    private var activity: NSObjectProtocol?
    private let watcher = USBWatcher()
    private var pending: Task<Void, Never>?
    private var quietUntil = Date.distantPast

    // MARK: Detecção automática (plug / unplug)

    func startWatching() {
        watcher.start(
            onAdded: { [weak self] in Task { @MainActor in self?.controllerPlugged() } },
            onRemoved: { [weak self] in Task { @MainActor in self?.controllerUnplugged() } })
    }

    private func controllerPlugged() {
        if isUpdating { return }                       // o controle reinicia durante a gravação
        if Date() < quietUntil, info != nil { return } // já releu a versão após o update
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(1))    // dá tempo da interface HID subir
            guard !Task.isCancelled, !isUpdating else { return }
            await refresh()
        }
    }

    private func controllerUnplugged() {
        if isUpdating || Date() < quietUntil { return }
        pending?.cancel()
        info = nil
        controllerDetails = nil
        latest = nil
        checkNote = nil
        availability = .unknown
        phase = .noController(appLocalized("Controle desconectado."))
    }
    var isUpdating: Bool { phase == .updating }

    // MARK: Leitura e verificação

    private var refreshing = false
    private var rerun = false

    func refresh() async {
        guard !isUpdating else { return }
        if refreshing { rerun = true; return }
        refreshing = true
        repeat {
            rerun = false
            await performRefresh()
        } while rerun && !isUpdating
        refreshing = false
    }

    private func performRefresh() async {
        if info == nil {
            phase = .loading
        }
        availability = .unknown
        latest = nil
        checkNote = nil

        let read = await CLI.run(["--print-firmware-info", "--json"], timeout: 20)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard read.status == 0,
              let json = read.lines.first(where: { $0.hasPrefix("{") }),
              let data = json.data(using: .utf8),
              let parsed = try? decoder.decode(ControllerInfo.self, from: data) else {
            info = nil
            phase = .noController(
                read.timedOut
                    ? appLocalized("Tempo limite excedido. Confira a conexão e tente novamente.")
                    : Self.tail(read.lines)
            )
            return
        }
        info = parsed
        phase = .ready

        var check = await CLI.run(["--check", "--path", parsed.path], timeout: 30)
        if check.status != 0, Self.isExclusiveHIDError(check.lines) {
            try? await Task.sleep(for: .milliseconds(500))
            check = await CLI.run(["--check", "--path", parsed.path], timeout: 30)
        }
        let result = FirmwareCheckParser.parse(lines: check.lines, currentVersion: parsed.versionHex)
        latest = result.latest
        availability = result.availability
        if check.status != 0 || availability == .unknown {
            if check.timedOut {
                checkNote = appLocalized("Tempo limite excedido. Confira a conexão e tente novamente.")
            } else if Self.isExclusiveHIDError(check.lines) {
                checkNote = appLocalized("O controle está ocupado por outro app ou processo do macOS. Feche jogos e ferramentas que possam usá-lo e tente novamente.")
            } else {
                checkNote = appLocalized("Não foi possível consultar a Sony:") + " " + Self.tail(check.lines)
            }
        }

        let previousDetails = controllerDetails
        let refreshedDetails = await Task.detached(priority: .userInitiated) {
            var details = ControllerDetails(serialNumber: nil, batteryLevel: nil, isCharging: nil)
            for attempt in 0..<3 {
                let next = ControllerDetailsReader.read()
                details = ControllerDetails(
                    serialNumber: next.serialNumber ?? details.serialNumber,
                    batteryLevel: next.batteryLevel ?? details.batteryLevel,
                    isCharging: next.isCharging ?? details.isCharging
                )
                if details.serialNumber != nil, details.batteryLevel != nil {
                    break
                }
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(400))
                }
            }
            return details
        }.value
        controllerDetails = ControllerDetails(
            serialNumber: refreshedDetails.serialNumber ?? previousDetails?.serialNumber,
            batteryLevel: refreshedDetails.batteryLevel ?? previousDetails?.batteryLevel,
            isCharging: refreshedDetails.isCharging ?? previousDetails?.isCharging
        )
    }

    // MARK: Instalação

    func install() async {
        guard let target = info, !isUpdating else { return }
        let expectedVersion = latest
        phase = .updating
        progress = 0
        log = []
        status = appLocalized("Preparando…")
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .userInitiated],
            reason: "Atualizando firmware do controle")

        let result = await CLI.run(
            ["--update-latest", "--yes", "--path", target.path],
            timeout: 600
        ) { line in
            Task { @MainActor in UpdaterModel.shared.handle(line) }
        }
        await Task.yield()
        quietUntil = Date().addingTimeInterval(12)
        if let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }

        if result.timedOut {
            phase = .failed(appLocalized("Tempo limite excedido. Confira a conexão e tente novamente."))
        } else if result.status == 0 {
            let summary = result.lines.last ?? appLocalized("Atualização concluída.")
            if await confirmInstalledVersion(previous: target.versionHex, expected: expectedVersion) {
                phase = .finished(summary)
            } else {
                phase = .failed(
                    appLocalized("Não foi possível confirmar a versão instalada. Reconecte o controle e confira antes de tentar novamente.")
                )
            }
        } else {
            phase = .failed(Self.tail(result.lines))
        }
    }

    private func handle(_ line: String) {
        log.append(line)
        if let m = line.range(of: #"Writing: (\d+)/(\d+) blocks"#, options: .regularExpression) {
            let nums = line[m].split(whereSeparator: { !$0.isNumber }).compactMap { Double($0) }
            if nums.count == 2, nums[1] > 0 {
                progress = nums[0] / nums[1]
                status = "\(appLocalized("Gravando firmware…")) \(Int(progress * 100))%"
            }
        } else if line.contains("Preparing firmware") {
            status = appLocalized("Baixando firmware da Sony…")
        } else if line.contains("Preparing controller") {
            status = appLocalized("Preparando o controle…")
        } else if line.contains("Verifying") {
            progress = 1
            status = appLocalized("Verificando no controle…")
        } else if line.contains("Finalization sent") {
            status = appLocalized("Finalizando…")
        }
    }

    private static func isExclusiveHIDError(_ lines: [String]) -> Bool {
        let output = lines.joined(separator: "\n").localizedLowercase
        return output.contains("exclusive access")
            || output.contains("device already open")
            || output.contains("e00002c5")
    }

    private static func tail(_ lines: [String]) -> String {
        let t = lines.suffix(3).joined(separator: "\n")
        return t.isEmpty ? appLocalized("Sem detalhes.") : t
    }

    private func confirmInstalledVersion(previous: String, expected: String?) async -> Bool {
        for _ in 0..<3 {
            try? await Task.sleep(for: .seconds(3))
            phase = .ready
            await refresh()

            guard let installed = info?.versionHex,
                  !FirmwareCheckParser.versionsMatch(installed, previous) else { continue }

            if let expected {
                return FirmwareCheckParser.versionsMatch(installed, expected)
            }
            return true
        }
        return false
    }
}
