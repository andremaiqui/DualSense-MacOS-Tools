import SwiftUI

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

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .portugueseBrazil
    }
}

func appLocalized(_ key: String, language: AppLanguage) -> String {
    Bundle.module.localizedString(
        forKey: key,
        value: key,
        table: "Localizable",
        localizations: [language.locale.language]
    )
}

struct SettingsView: View {
    @AppStorage("appLanguage") private var selectedLanguage = AppLanguage.portugueseBrazil.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .portugueseBrazil
    }

    var body: some View {
        Form {
            Picker(appLocalized("Idioma do app", language: appLanguage), selection: $selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.name).tag(language.rawValue)
                }
            }
        }
        .formStyle(.grouped)
        .scenePadding()
        .frame(width: 360)
    }
}
