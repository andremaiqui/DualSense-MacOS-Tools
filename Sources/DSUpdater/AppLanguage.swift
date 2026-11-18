import SwiftUI
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case portugueseBrazil = "pt-BR"
    case englishUnitedStates = "en-US"
    case spanishLatinAmerica = "es-419"
    case spanishSpain = "es-ES"
    case japanese = "ja"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case korean = "ko"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var name: String {
        switch self {
        case .portugueseBrazil:
            "Português (Brasil)"
        case .englishUnitedStates:
            "English (United States)"
        case .spanishLatinAmerica:
            "Español (Latinoamérica)"
        case .spanishSpain:
            "Español (España)"
        case .japanese:
            "日本語"
        case .french:
            "Français"
        case .german:
            "Deutsch"
        case .italian:
            "Italiano"
        case .korean:
            "한국어"
        }
    }

}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var localizationKey: String {
        switch self {
        case .system: "Padrão do sistema"
        case .light: "Claro"
        case .dark: "Escuro"
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        }
    }

    var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
        }
    }

    private init() {
        language = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        ) ?? .portugueseBrazil
        appearance = AppAppearance(
            rawValue: UserDefaults.standard.string(forKey: "appAppearance") ?? ""
        ) ?? .system
    }
}

func appLocalized(_ key: String, language: AppLanguage) -> String {
    guard let localizationPath = Bundle.module.path(
        forResource: language.rawValue,
        ofType: "lproj"
    ), let localizationBundle = Bundle(path: localizationPath) else {
        return key
    }

    return localizationBundle.localizedString(
        forKey: key,
        value: key,
        table: "Localizable"
    )
}

func appLocalized(_ key: String) -> String {
    let language = AppLanguage(
        rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? ""
    ) ?? .portugueseBrazil
    return appLocalized(key, language: language)
}

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 12) {
            Text("Settings")
                .font(.headline)
                .frame(maxWidth: .infinity)

            Form {
                Picker(appLocalized("Idioma do app", language: settings.language), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.name).tag(language)
                    }
                }
                Picker(appLocalized("Aparência", language: settings.language), selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appLocalized(appearance.localizationKey, language: settings.language))
                            .tag(appearance)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .scenePadding()
        .padding(.top, 10)
        .frame(width: 360, height: 220)
    }
}
