import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: "Version 0.1.0 (Developers: Andre Maiqui, Ollie Judge, nchie, VolksDroid)"
        ])
    }

    /// Faz o app aparecer no Dock e vir para a frente, mesmo rodando direto do Xcode/SwiftPM.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Barra de título contínua com o conteúdo, sem linha separando os botões do semáforo.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main
        ) { note in
            (note.object as? NSWindow).map(Self.blendTitlebar)
        }
        DispatchQueue.main.async { NSApp.windows.forEach(Self.blendTitlebar) }
    }

    private static func blendTitlebar(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Impede sair do app enquanto o firmware está sendo gravado.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let busy = MainActor.assumeIsolated { UpdaterModel.shared.isUpdating }
        if busy {
            let alert = NSAlert()
            alert.messageText = appLocalized("Atualização em andamento")
            alert.informativeText = appLocalized("Sair agora pode danificar o controle. Aguarde terminar.")
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
}

@main
struct DSUpdaterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let settings = AppSettings.shared

    private var appLanguage: AppLanguage {
        settings.language
    }

    var body: some Scene {
        WindowGroup(appLocalized("Firmware do controle", language: appLanguage)) {
            ContentView()
                .environment(\.locale, appLanguage.locale)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About DS Updater") {
                    AppDelegate.showAboutPanel()
                }
            }
        }

        Settings {
            SettingsView()
                .environment(\.locale, appLanguage.locale)
        }
        .defaultSize(width: 360, height: 120)
        .windowResizability(.contentSize)
    }
}
