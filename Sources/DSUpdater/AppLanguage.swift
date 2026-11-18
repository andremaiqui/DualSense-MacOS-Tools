import SwiftUI
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case portugueseBrazil = "pt-BR"
    case englishUnitedStates = "en-US"

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

    private init() {
        language = AppLanguage(
            rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        ) ?? .portugueseBrazil
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
        Form {
            Picker(appLocalized("Idioma do app", language: settings.language), selection: $settings.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.name).tag(language)
                }
            }
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(width: 360, height: 120)
    }
}
