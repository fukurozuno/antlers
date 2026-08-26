import Foundation
import MafxCore

enum L10n {
    private static let fallbackLanguageCode = "en"
    private static let supportedLanguageCodes = ["en", "ja"]
    private static var appLanguage: AppLanguage = .system
    private static var resourceDirectoryForTesting: URL?

    static func setAppLanguage(_ language: AppLanguage) {
        appLanguage = language
    }

    static func setResourceDirectoryForTesting(_ directory: URL?) {
        resourceDirectoryForTesting = directory
    }

    static func string(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }

    private static var localizedBundle: Bundle {
        bundle(for: effectiveLanguageCode) ?? fallbackBundle
    }

    private static var fallbackBundle: Bundle {
        bundle(for: fallbackLanguageCode) ?? .main
    }

    private static var effectiveLanguageCode: String {
        if let resourceCode = appLanguage.resourceCode {
            return resourceCode
        }

        let preferredLanguageCodes = Locale.preferredLanguages
            .map { Locale(identifier: $0).language.languageCode?.identifier ?? $0 }
        return preferredLanguageCodes.first { supportedLanguageCodes.contains($0) } ?? fallbackLanguageCode
    }

    private static func bundle(for languageCode: String) -> Bundle? {
        if let resourceDirectoryForTesting {
            return Bundle(url: resourceDirectoryForTesting.appendingPathComponent("\(languageCode).lproj"))
        }

        if let mainBundleResourceURL = Bundle.main.url(forResource: languageCode, withExtension: "lproj"),
           let mainBundle = Bundle(url: mainBundleResourceURL) {
            return mainBundle
        }

        let projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let developmentResourceURL = projectDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("MafxApp", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("\(languageCode).lproj", isDirectory: true)
        return Bundle(url: developmentResourceURL)
    }
}

extension AppLanguage {
    var localizedTitle: String {
        switch self {
        case .system:
            return L10n.string("settings.language.system")
        case .english:
            return L10n.string("settings.language.english")
        case .japanese:
            return L10n.string("settings.language.japanese")
        }
    }
}

extension StartupPathMode {
    var localizedTitle: String {
        switch self {
        case .previous:
            return L10n.string("settings.startupPathMode.previous")
        case .specified:
            return L10n.string("settings.startupPathMode.specified")
        }
    }
}

extension ReturnKeyBehavior {
    var localizedTitle: String {
        switch self {
        case .openSelectedDirectory:
            return L10n.string("settings.returnKeyBehavior.openSelectedDirectory")
        case .previewFileOrOpenDirectory:
            return L10n.string("settings.returnKeyBehavior.previewFileOrOpenDirectory")
        case .disabled:
            return L10n.string("settings.returnKeyBehavior.disabled")
        }
    }
}

extension PreviewPanePosition {
    var localizedTitle: String {
        L10n.string(self == .right ? "settings.previewPanePosition.right" : "settings.previewPanePosition.left")
    }
}

extension IncrementalSearchMatchMode {
    var localizedTitle: String {
        switch self {
        case .prefix:
            return L10n.string("settings.incrementalSearchMatchMode.prefix")
        case .contains:
            return L10n.string("settings.incrementalSearchMatchMode.contains")
        case .exact:
            return L10n.string("settings.incrementalSearchMatchMode.exact")
        }
    }
}

extension SettingsTab {
    var localizedTitle: String {
        localizationKey.map(L10n.string) ?? title
    }
}

extension SettingsItem {
    var localizedTitle: String {
        localizationKey.map(L10n.string) ?? title
    }
}

extension CommandID {
    var localizedTitle: String {
        L10n.string(localizationKey)
    }
}

extension KeyBindingCategory {
    var localizedTitle: String {
        L10n.string(localizationKey)
    }
}

extension DisplayColorRole {
    var localizedTitle: String {
        L10n.string(localizationKey)
    }
}

extension FileSortCriterion {
    var localizedDisplayName: String {
        switch self {
        case .name:
            return L10n.string("sort.name")
        case .fileExtension:
            return L10n.string("sort.extension")
        case .byteSize:
            return L10n.string("sort.size")
        case .modificationDate:
            return L10n.string("sort.modified")
        }
    }
}

extension SortDirection {
    var localizedDisplaySymbol: String {
        switch self {
        case .ascending:
            return L10n.string("sortDirection.ascending")
        case .descending:
            return L10n.string("sortDirection.descending")
        }
    }
}

extension FileSortDescriptor {
    var localizedDisplayText: String {
        "\(criterion.localizedDisplayName) \(direction.localizedDisplaySymbol)"
    }
}
