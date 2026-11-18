import SwiftUI

enum AppWindowRole {
    case main
    case settings
}

struct WindowConfigurator: NSViewRepresentable {
    let role: AppWindowRole

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                AppDelegate.configure(window, as: role)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                AppDelegate.configure(window, as: role)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: "Version 0.1.0 (Developers: Andre Maiqui, Ollie Judge, nchie, VolksDroid)"
        ])
        DispatchQueue.main.async {
            if let aboutWindow = NSApp.keyWindow {
                configureAboutPanel(aboutWindow)
            }
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

    static func configure(_ window: NSWindow, as role: AppWindowRole) {
        configureChrome(of: window)

        switch role {
        case .main:
            window.title = "DSUpdater"
            window.miniwindowTitle = "DSUpdater"
            removeWindowTitle(from: window)
        case .settings:
            window.title = "Settings"
            window.isMovableByWindowBackground = true
            window.isExcludedFromWindowsMenu = true
            installWindowTitle("Settings", in: window)
        }
    }

    private static func configureWindow(_ window: NSWindow) {
        if window.title.localizedCaseInsensitiveContains("settings") {
            configure(window, as: .settings)
            return
        }

        if window.title.localizedCaseInsensitiveContains("about") {
            configureAboutPanel(window)
            return
        }

        configure(window, as: .main)
    }

    private static func configureAboutPanel(_ window: NSWindow) {
        configureChrome(of: window)
        window.title = "About"
        installWindowTitle("About", in: window)
    }

    private static func configureChrome(of window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
    }

    private static func installWindowTitle(_ title: String, in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        if let label = contentView.subviews.first(where: {
            $0.identifier == NSUserInterfaceItemIdentifier("DSUpdater.WindowTitle")
        }) as? NSTextField {
            label.stringValue = title
            return
        }

        let label = NSTextField(labelWithString: title)
        label.identifier = NSUserInterfaceItemIdentifier("DSUpdater.WindowTitle")
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.alignment = .center
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16)
        ])
    }

    private static func removeWindowTitle(from window: NSWindow) {
        window.contentView?.subviews.first(where: {
            $0.identifier == NSUserInterfaceItemIdentifier("DSUpdater.WindowTitle")
        })?.removeFromSuperview()
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
                .background(WindowConfigurator(role: .main))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About DSUpdater") {
                    AppDelegate.showAboutPanel()
                }
            }
        }

        Settings {
            SettingsView()
                .environment(\.locale, appLanguage.locale)
                .background(WindowConfigurator(role: .settings))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 360, height: 220)
        .windowResizability(.contentSize)
    }
}
