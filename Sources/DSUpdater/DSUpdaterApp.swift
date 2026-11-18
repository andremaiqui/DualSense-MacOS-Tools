import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: "Version 0.1.0 (Developers: Andre Maiqui, Ollie Judge, nchie, VolksDroid)"
        ])
        if let aboutWindow = NSApp.keyWindow {
            configureAboutPanel(aboutWindow)
        }
    }

    /// Faz o app aparecer no Dock e vir para a frente, mesmo rodando direto do Xcode/SwiftPM.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        AppSettings.shared.applyAppearance()
        // Barra de título contínua com o conteúdo, sem linha separando os botões do semáforo.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main
        ) { note in
            (note.object as? NSWindow).map(Self.configureWindow)
        }
        DispatchQueue.main.async { NSApp.windows.forEach(Self.configureWindow) }
    }

    private static func configureWindow(_ window: NSWindow) {
        if window.title.localizedCaseInsensitiveContains("settings") {
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.titleVisibility = .hidden
            window.title = "Settings"
            window.isMovableByWindowBackground = true
            window.isExcludedFromWindowsMenu = true
            return
        }

        if window.title.localizedCaseInsensitiveContains("about") {
            configureAboutPanel(window)
            return
        }

        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.title = "DSUpdater"
        window.miniwindowTitle = "DSUpdater"
    }

    private static func configureAboutPanel(_ window: NSWindow) {
        window.title = ""
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

    private var appAppearance: AppAppearance {
        settings.appearance
    }

    var body: some Scene {
        WindowGroup(appLocalized("Firmware do controle", language: appLanguage)) {
            ContentView()
                .environment(\.locale, appLanguage.locale)
                .animation(.easeInOut(duration: 0.35), value: appAppearance)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About") {
                    AppDelegate.showAboutPanel()
                }
            }
        }

        Settings {
            SettingsView()
                .environment(\.locale, appLanguage.locale)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 360, height: 220)
        .windowResizability(.contentSize)
    }
}
