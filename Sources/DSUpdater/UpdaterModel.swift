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
    enum Availability { case unknown, upToDate, available }

    @Published var phase: Phase = .loading
    @Published var info: ControllerInfo?
    @Published var latest: String?
    @Published var availability: Availability = .unknown
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
        phase = .loading
        availability = .unknown
        latest = nil
        checkNote = nil

        let read = await CLI.run(["--print-firmware-info", "--json"])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard read.status == 0,
              let json = read.lines.first(where: { $0.hasPrefix("{") }),
              let data = json.data(using: .utf8),
              let parsed = try? decoder.decode(ControllerInfo.self, from: data) else {
            info = nil
            phase = .noController(Self.tail(read.lines))
            return
        }
        info = parsed
        phase = .ready

        let check = await CLI.run(["--check", "--path", parsed.path])
        for line in check.lines {
            if let r = line.range(of: "Latest on Sony's server:") {
                latest = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
            }
            if line.contains("No newer firmware") { availability = .upToDate }
            if line.contains("Update available") { availability = .available }
        }
        if check.status != 0 || availability == .unknown {
            checkNote = appLocalized("Não foi possível consultar a Sony:") + " " + Self.tail(check.lines)
        }
    }

    // MARK: Instalação

    func install() async {
        guard let target = info, !isUpdating else { return }
        phase = .updating
        progress = 0
        log = []
        status = appLocalized("Preparando…")
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .userInitiated],
            reason: "Atualizando firmware do controle")

        let result = await CLI.run(["--update-latest", "--yes", "--path", target.path]) { line in
            Task { @MainActor in UpdaterModel.shared.handle(line) }
        }
        await Task.yield()
        quietUntil = Date().addingTimeInterval(12)
        if let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }

        if result.status == 0 {
            let summary = result.lines.last ?? appLocalized("Atualização concluída.")
            try? await Task.sleep(nanoseconds: 3_000_000_000) // o controle reinicia
            phase = .ready
            await refresh()
            if info != nil { phase = .finished(summary) }
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

    private static func tail(_ lines: [String]) -> String {
        let t = lines.suffix(3).joined(separator: "\n")
        return t.isEmpty ? "Sem detalhes." : t
    }
}
