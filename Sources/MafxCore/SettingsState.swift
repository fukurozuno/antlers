import Foundation

public struct SettingsTab: Equatable {
    public let title: String
    public let localizationKey: String?
    public let items: [SettingsItem]

    public init(title: String, localizationKey: String? = nil, items: [SettingsItem]) {
        self.title = title
        self.localizationKey = localizationKey
        self.items = items
    }
}

public struct SettingsItem: Equatable {
    public let title: String
    public let localizationKey: String?
    public let toggleID: SettingsToggleID?
    public let choiceID: SettingsChoiceID?
    public let numericID: SettingsNumericID?

    public init(
        title: String,
        localizationKey: String? = nil,
        toggleID: SettingsToggleID? = nil,
        choiceID: SettingsChoiceID? = nil,
        numericID: SettingsNumericID? = nil
    ) {
        self.title = title
        self.localizationKey = localizationKey
        self.toggleID = toggleID
        self.choiceID = choiceID
        self.numericID = numericID
    }
}

public struct JumpPathEntry: Codable, Equatable {
    public var displayName: String
    public var path: String

    public init(displayName: String = "", path: String) {
        self.displayName = displayName
        self.path = path
    }

    public var listTitle: String {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDisplayName.isEmpty ? path : trimmedDisplayName
    }

    public var normalizedPath: String {
        Self.normalizedPath(path)
    }

    public static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

/// 拡張子または未登録拡張子ごとの起動アプリケーションと表示色をまとめた設定です。
public struct FileTypeAssociation: Codable, Equatable, Identifiable {
    public var id: UUID
    public var extensions: [String]
    /// `true` の場合、具体的な拡張子が登録されていない通常ファイルに適用します。
    public var matchesOtherExtensions: Bool
    /// アプリケーションバンドルのパス。空文字列は未指定を表します。
    public var applicationPath: String
    public var color: DisplayColor?

    public init(
        id: UUID = UUID(),
        extensions: [String],
        matchesOtherExtensions: Bool = false,
        applicationPath: String = "",
        color: DisplayColor? = nil
    ) {
        self.id = id
        self.matchesOtherExtensions = matchesOtherExtensions
        self.extensions = matchesOtherExtensions ? [] : Self.normalizedExtensions(extensions)
        self.applicationPath = applicationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        self.color = color
    }

    public var extensionsText: String { extensions.joined(separator: ",") }
    public var isOtherExtensionsAssociation: Bool { matchesOtherExtensions }

    public static func other(
        id: UUID = UUID(),
        applicationPath: String = "",
        color: DisplayColor? = nil
    ) -> FileTypeAssociation {
        FileTypeAssociation(
            id: id,
            extensions: [],
            matchesOtherExtensions: true,
            applicationPath: applicationPath,
            color: color
        )
    }

    public func matches(fileExtension: String) -> Bool {
        !matchesOtherExtensions && extensions.contains(Self.normalizedExtension(fileExtension))
    }

    public static func normalizedExtensions(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .flatMap { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
            .map(normalizedExtension)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public static func normalizedExtension(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }

    /// 複数のファイル別設定に重複して含まれる拡張子を、最初に検出した順で返します。
    public static func duplicateExtensions(in associations: [FileTypeAssociation]) -> [String] {
        var seen = Set<String>()
        var duplicates: [String] = []

        for association in associations {
            for fileExtension in normalizedExtensions(association.extensions) {
                if !seen.insert(fileExtension).inserted, !duplicates.contains(fileExtension) {
                    duplicates.append(fileExtension)
                }
            }
        }

        return duplicates
    }

    public static func hasDuplicateOtherExtensionsAssociation(in associations: [FileTypeAssociation]) -> Bool {
        associations.filter(\.matchesOtherExtensions).count > 1
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case extensions
        case matchesOtherExtensions
        case applicationPath
        case color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        matchesOtherExtensions = try container.decodeIfPresent(Bool.self, forKey: .matchesOtherExtensions) ?? false
        extensions = matchesOtherExtensions
            ? []
            : Self.normalizedExtensions(try container.decodeIfPresent([String].self, forKey: .extensions) ?? [])
        applicationPath = (try container.decodeIfPresent(String.self, forKey: .applicationPath) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        color = try container.decodeIfPresent(DisplayColor.self, forKey: .color)
    }
}

/// ファイル別設定を解決します。具体的な拡張子は「その他」より常に優先されます。
public struct FileTypeAssociationResolver {
    private let associations: [FileTypeAssociation]

    public init(associations: [FileTypeAssociation]) {
        self.associations = associations
    }

    public func association(forFileExtension fileExtension: String) -> FileTypeAssociation? {
        if let exactMatch = associations.first(where: { $0.matches(fileExtension: fileExtension) }) {
            return exactMatch
        }
        return associations.first(where: \.matchesOtherExtensions)
    }
}

public enum FileTypeColorScope: String, Codable, Equatable, CaseIterable {
    case fileName
    case fileExtension
}

public struct DisplayColor: Codable, Equatable {
    public static let minimumPaneBackgroundAlpha = 0.75

    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = Self.clamped(red)
        self.green = Self.clamped(green)
        self.blue = Self.clamped(blue)
        self.alpha = Self.clamped(alpha)
    }

    public init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: value)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xff) / 255.0,
            green: Double((rgb >> 8) & 0xff) / 255.0,
            blue: Double(rgb & 0xff) / 255.0,
            alpha: 1.0
        )
    }

    public var hexString: String {
        let redValue = Int(round(red * 255.0))
        let greenValue = Int(round(green * 255.0))
        let blueValue = Int(round(blue * 255.0))
        return String(format: "#%02X%02X%02X", redValue, greenValue, blueValue)
    }

    public var paneBackgroundAlpha: Double {
        min(1.0, max(Self.minimumPaneBackgroundAlpha, alpha))
    }

    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
        case alpha
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue),
            alpha: try container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1.0
        )
    }

    private static func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}

public struct DisplayColorPair: Codable, Equatable {
    public var background: DisplayColor?
    public var foreground: DisplayColor?

    public init(background: DisplayColor? = nil, foreground: DisplayColor? = nil) {
        self.background = background
        self.foreground = foreground
    }
}

public enum DisplayColorRole: String, Codable, CaseIterable, Equatable {
    case base
    case selected
    case marked
    case folder
    case message
    case focus

    public var title: String {
        switch self {
        case .base:
            return "基本"
        case .selected:
            return "選択中"
        case .marked:
            return "マーク中"
        case .folder:
            return "フォルダ"
        case .message:
            return "メッセージエリア"
        case .focus:
            return "フォーカス中"
        }
    }

    public var localizationKey: String {
        "displayColorRole.\(rawValue)"
    }
}

public struct DisplayTheme: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var base: DisplayColorPair
    public var selected: DisplayColorPair
    public var marked: DisplayColorPair
    public var folder: DisplayColorPair
    public var message: DisplayColorPair
    public var focus: DisplayColorPair

    public init(
        id: String,
        name: String,
        base: DisplayColorPair,
        selected: DisplayColorPair = DisplayColorPair(),
        marked: DisplayColorPair = DisplayColorPair(),
        folder: DisplayColorPair = DisplayColorPair(),
        message: DisplayColorPair = DisplayColorPair(),
        focus: DisplayColorPair = DisplayColorPair()
    ) {
        self.id = id
        self.name = name
        self.base = base
        self.selected = selected
        self.marked = marked
        self.folder = folder
        self.message = message
        self.focus = focus
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case base
        case selected
        case marked
        case folder
        case message
        case focus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        base = try container.decode(DisplayColorPair.self, forKey: .base)
        selected = try container.decodeIfPresent(DisplayColorPair.self, forKey: .selected) ?? DisplayColorPair()
        marked = try container.decodeIfPresent(DisplayColorPair.self, forKey: .marked) ?? DisplayColorPair()
        folder = try container.decodeIfPresent(DisplayColorPair.self, forKey: .folder) ?? DisplayColorPair()
        message = try container.decodeIfPresent(DisplayColorPair.self, forKey: .message) ?? DisplayColorPair()
        focus = try container.decodeIfPresent(DisplayColorPair.self, forKey: .focus) ?? DisplayColorPair()
    }

    public func colorPair(for role: DisplayColorRole) -> DisplayColorPair {
        switch role {
        case .base:
            return base
        case .selected:
            return selected
        case .marked:
            return marked
        case .folder:
            return folder
        case .message:
            return message
        case .focus:
            return focus
        }
    }

    public mutating func setColorPair(_ pair: DisplayColorPair, for role: DisplayColorRole) {
        switch role {
        case .base:
            base = pair
        case .selected:
            selected = pair
        case .marked:
            marked = pair
        case .folder:
            folder = pair
        case .message:
            message = pair
        case .focus:
            focus = pair
        }
    }

    public func resolvedColorPair(isSelected: Bool, isMarked: Bool, isDirectory: Bool) -> DisplayColorPair {
        let fallbackOrder: [DisplayColorPair] = [
            isSelected ? selected : DisplayColorPair(),
            isMarked ? marked : DisplayColorPair(),
            isDirectory ? folder : DisplayColorPair(),
            base
        ]

        return DisplayColorPair(
            background: fallbackOrder.compactMap(\.background).first,
            foreground: fallbackOrder.compactMap(\.foreground).first
        )
    }

    public var resolvedMessageColorPair: DisplayColorPair {
        DisplayColorPair(
            background: message.background ?? base.background,
            foreground: message.foreground ?? base.foreground
        )
    }

    public var resolvedFocusColorPair: DisplayColorPair {
        DisplayColorPair(
            background: focus.background,
            foreground: focus.foreground
        )
    }
}

public struct DisplayThemeSet: Codable, Equatable {
    public static let protectedThemeIDs = Set(DisplayTheme.defaultThemes.map(\.id))

    public var selectedThemeID: String
    public var themes: [DisplayTheme]

    public init(selectedThemeID: String = DisplayTheme.light.id, themes: [DisplayTheme] = DisplayTheme.defaultThemes) {
        self.themes = themes.isEmpty ? DisplayTheme.defaultThemes : themes
        self.selectedThemeID = self.themes.contains { $0.id == selectedThemeID } ? selectedThemeID : self.themes[0].id
    }

    public var selectedTheme: DisplayTheme {
        themes.first { $0.id == selectedThemeID } ?? themes[0]
    }

    public var canEditSelectedTheme: Bool {
        !Self.protectedThemeIDs.contains(selectedThemeID)
    }

    public var canDeleteSelectedTheme: Bool {
        !Self.protectedThemeIDs.contains(selectedThemeID)
    }

    public mutating func selectTheme(id: String) {
        guard themes.contains(where: { $0.id == id }) else {
            return
        }

        selectedThemeID = id
    }

    @discardableResult
    public mutating func updateSelectedTheme(_ theme: DisplayTheme) -> Bool {
        guard canEditSelectedTheme else {
            return false
        }

        guard let index = themes.firstIndex(where: { $0.id == selectedThemeID }) else {
            themes.append(theme)
            selectedThemeID = theme.id
            return true
        }

        var updatedTheme = theme
        updatedTheme.id = selectedThemeID
        themes[index] = updatedTheme
        return true
    }

    @discardableResult
    public mutating func addThemeFromCurrent(named name: String, id: String = UUID().uuidString) -> DisplayTheme {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var theme = selectedTheme
        theme.id = id
        theme.name = trimmedName.isEmpty ? "Custom Theme" : trimmedName
        themes.append(theme)
        selectedThemeID = theme.id
        return theme
    }

    @discardableResult
    public mutating func deleteSelectedTheme() -> Bool {
        guard canDeleteSelectedTheme,
              let index = themes.firstIndex(where: { $0.id == selectedThemeID }) else {
            return false
        }

        themes.remove(at: index)
        if themes.isEmpty {
            themes = DisplayTheme.defaultThemes
        }
        selectedThemeID = themes[min(index, themes.count - 1)].id
        return true
    }
}

public extension DisplayTheme {
    static let light = DisplayTheme(
        id: "light",
        name: "Light",
        base: DisplayColorPair(background: DisplayColor(hex: "#FFFFFF"), foreground: DisplayColor(hex: "#1F2328")),
        selected: DisplayColorPair(background: DisplayColor(hex: "#0A84FF"), foreground: DisplayColor(hex: "#FFFFFF")),
        marked: DisplayColorPair(background: DisplayColor(hex: "#FFF3B0"), foreground: DisplayColor(hex: "#1F2328")),
        folder: DisplayColorPair(background: nil, foreground: DisplayColor(hex: "#0057B8")),
        message: DisplayColorPair(background: nil, foreground: nil),
        focus: DisplayColorPair(background: DisplayColor(hex: "#0A84FF"), foreground: DisplayColor(hex: "#0A84FF"))
    )

    static let dark = DisplayTheme(
        id: "dark",
        name: "Dark",
        base: DisplayColorPair(background: DisplayColor(hex: "#111111"), foreground: DisplayColor(hex: "#E6E6E6")),
        selected: DisplayColorPair(background: DisplayColor(hex: "#0A84FF"), foreground: DisplayColor(hex: "#FFFFFF")),
        marked: DisplayColorPair(background: DisplayColor(hex: "#5A4A00"), foreground: DisplayColor(hex: "#FFF4B8")),
        folder: DisplayColorPair(background: nil, foreground: DisplayColor(hex: "#7AB7FF")),
        message: DisplayColorPair(background: nil, foreground: nil),
        focus: DisplayColorPair(background: DisplayColor(hex: "#0A84FF"), foreground: DisplayColor(hex: "#0A84FF"))
    )

    static let solarizedLight = DisplayTheme(
        id: "solarized-light",
        name: "Solarized Light",
        base: DisplayColorPair(background: DisplayColor(hex: "#FDF6E3"), foreground: DisplayColor(hex: "#657B83")),
        selected: DisplayColorPair(background: DisplayColor(hex: "#EEE8D5"), foreground: DisplayColor(hex: "#073642")),
        marked: DisplayColorPair(background: DisplayColor(hex: "#EEE8D5"), foreground: DisplayColor(hex: "#B58900")),
        folder: DisplayColorPair(background: nil, foreground: DisplayColor(hex: "#268BD2")),
        message: DisplayColorPair(background: nil, foreground: nil),
        focus: DisplayColorPair(background: DisplayColor(hex: "#2AA198"), foreground: DisplayColor(hex: "#2AA198"))
    )

    static let solarizedDark = DisplayTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        base: DisplayColorPair(background: DisplayColor(hex: "#002B36"), foreground: DisplayColor(hex: "#839496")),
        selected: DisplayColorPair(background: DisplayColor(hex: "#586E75"), foreground: DisplayColor(hex: "#FDF6E3")),
        marked: DisplayColorPair(background: DisplayColor(hex: "#073642"), foreground: DisplayColor(hex: "#B58900")),
        folder: DisplayColorPair(background: nil, foreground: DisplayColor(hex: "#268BD2")),
        message: DisplayColorPair(background: nil, foreground: nil),
        focus: DisplayColorPair(background: DisplayColor(hex: "#2AA198"), foreground: DisplayColor(hex: "#2AA198"))
    )

    static let nord = DisplayTheme(
        id: "nord",
        name: "Nord",
        base: DisplayColorPair(background: DisplayColor(hex: "#2E3440"), foreground: DisplayColor(hex: "#D8DEE9")),
        selected: DisplayColorPair(background: DisplayColor(hex: "#434C5E"), foreground: DisplayColor(hex: "#ECEFF4")),
        marked: DisplayColorPair(background: DisplayColor(hex: "#3B4252"), foreground: DisplayColor(hex: "#EBCB8B")),
        folder: DisplayColorPair(background: nil, foreground: DisplayColor(hex: "#88C0D0")),
        message: DisplayColorPair(background: nil, foreground: nil),
        focus: DisplayColorPair(background: DisplayColor(hex: "#88C0D0"), foreground: DisplayColor(hex: "#88C0D0"))
    )

    static let dracula = DisplayTheme(
        id: "dracula",
        name: "Dracula",
        base: DisplayColorPair(background: DisplayColor(hex: "#282A36"), foreground: DisplayColor(hex: "#F8F8F2")),
        selected: DisplayColorPair(background: DisplayColor(hex: "#44475A"), foreground: DisplayColor(hex: "#F8F8F2")),
        marked: DisplayColorPair(background: DisplayColor(hex: "#44475A"), foreground: DisplayColor(hex: "#F1FA8C")),
        folder: DisplayColorPair(background: nil, foreground: DisplayColor(hex: "#8BE9FD")),
        message: DisplayColorPair(background: nil, foreground: nil),
        focus: DisplayColorPair(background: DisplayColor(hex: "#BD93F9"), foreground: DisplayColor(hex: "#BD93F9"))
    )

    static let defaultThemes: [DisplayTheme] = [.light, .dark, .solarizedLight, .solarizedDark, .nord, .dracula]
}

public enum SettingsToggleID: Equatable {
    case showPreviewPane
    case showHiddenFiles
    case useAlternatingRowBackgrounds
    case showFileIcons
    case showFileTagColors
    case showFileExtensionsSeparately
    case showMultiStrokeKeyCandidates
    case moveCursorAfterMarking
    case moveToCreatedFolder
    case selectPreviousDirectoryAfterMovingToParent
    case confirmBeforeCopy
    case confirmBeforeMove
    case confirmBeforeTrash
    case confirmBeforeQuit
    case allowExternalFileDrag
}

public enum SettingsChoiceID: Equatable {
    case previewPanePosition
    case appLanguage
    case returnKeyBehavior
    case incrementalSearchMatchMode
    case leftStartupPathMode
    case rightStartupPathMode
}

public enum SettingsNumericID: Equatable {
    case fileOperationDetailLogLimit
    case fileListFontSize
}

public enum FileListFontSize {
    public static let minimum = 8
    public static let standard = 13
    public static let maximum = 24

    public static func normalized(_ value: Int) -> Int {
        min(maximum, max(minimum, value))
    }
}

public enum AppLanguage: String, Codable, Equatable, CaseIterable {
    case system
    case english = "en"
    case japanese = "ja"

    public var resourceCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return rawValue
        case .japanese:
            return rawValue
        }
    }
}

public enum StartupPathMode: String, Codable, Equatable, CaseIterable {
    case previous
    case specified
}

public enum ReturnKeyBehavior: String, Codable, Equatable, CaseIterable {
    case openSelectedDirectory
    case previewFileOrOpenDirectory
    case disabled
}

public enum PreviewPanePosition: String, Codable, Equatable, CaseIterable {
    case left
    case right
}

public extension IncrementalSearchMatchMode {
    var next: IncrementalSearchMatchMode {
        let values = Self.allCases
        guard let index = values.firstIndex(of: self) else { return .prefix }
        return values[(index + 1) % values.count]
    }
}

public enum SettingsChoiceValue: Equatable {
    case appLanguage(AppLanguage)
    case returnKeyBehavior(ReturnKeyBehavior)
    case incrementalSearchMatchMode(IncrementalSearchMatchMode)
    case startupPathMode(StartupPathMode)
    case previewPanePosition(PreviewPanePosition)
}

private extension StartupPathMode {
    var next: StartupPathMode {
        switch self {
        case .previous:
            return .specified
        case .specified:
            return .previous
        }
    }
}

private extension ReturnKeyBehavior {
    var next: ReturnKeyBehavior {
        switch self {
        case .openSelectedDirectory:
            return .previewFileOrOpenDirectory
        case .previewFileOrOpenDirectory:
            return .disabled
        case .disabled:
            return .openSelectedDirectory
        }
    }
}

public enum SettingsFocusArea: Equatable {
    case tabs
    case items
}

public struct SettingsState: Equatable {
    public private(set) var tabs: [SettingsTab]
    public private(set) var selectedTabIndex: Int
    public private(set) var focusedItemIndex: Int
    public private(set) var focusArea: SettingsFocusArea
    public private(set) var showsHiddenFiles: Bool
    public private(set) var showsPreviewPane: Bool
    public private(set) var usesAlternatingRowBackgrounds: Bool
    public private(set) var showsFileIcons: Bool
    public private(set) var showsFileTagColors: Bool
    public private(set) var showsFileExtensionsSeparately: Bool
    public private(set) var showsMultiStrokeKeyCandidates: Bool
    public private(set) var movesCursorAfterMarking: Bool
    public private(set) var movesToCreatedFolder: Bool
    public private(set) var selectsPreviousDirectoryAfterMovingToParent: Bool
    public private(set) var confirmsBeforeCopy: Bool
    public private(set) var confirmsBeforeMove: Bool
    public private(set) var confirmsBeforeTrash: Bool
    public private(set) var confirmsBeforeQuit: Bool
    public private(set) var allowsExternalFileDrag: Bool
    public private(set) var fileOperationDetailLogLimit: Int
    public private(set) var fileListFontSize: Int
    public private(set) var appLanguage: AppLanguage
    public private(set) var returnKeyBehavior: ReturnKeyBehavior
    public private(set) var incrementalSearchMatchMode: IncrementalSearchMatchMode
    public private(set) var previewPanePosition: PreviewPanePosition
    public private(set) var leftStartupPathMode: StartupPathMode
    public private(set) var rightStartupPathMode: StartupPathMode
    public private(set) var leftStartupPath: String
    public private(set) var rightStartupPath: String
    public private(set) var jumpPathEntries: [JumpPathEntry]
    public private(set) var keyBindingSet: KeyBindingSet
    public private(set) var displayThemeSet: DisplayThemeSet
    public private(set) var fileTypeAssociations: [FileTypeAssociation]
    public private(set) var fileTypeColorScope: FileTypeColorScope

    public init(
        tabs: [SettingsTab] = SettingsState.defaultTabs,
        selectedTabIndex: Int = 0,
        focusedItemIndex: Int = 0,
        focusArea: SettingsFocusArea = .items,
        showsHiddenFiles: Bool = false,
        showsPreviewPane: Bool = false,
        usesAlternatingRowBackgrounds: Bool = false,
        showsFileIcons: Bool = true,
        showsFileTagColors: Bool = true,
        showsFileExtensionsSeparately: Bool = true,
        showsMultiStrokeKeyCandidates: Bool = true,
        movesCursorAfterMarking: Bool = true,
        movesToCreatedFolder: Bool = true,
        selectsPreviousDirectoryAfterMovingToParent: Bool = true,
        confirmsBeforeCopy: Bool = true,
        confirmsBeforeMove: Bool = true,
        confirmsBeforeTrash: Bool = true,
        confirmsBeforeQuit: Bool = true,
        allowsExternalFileDrag: Bool = false,
        fileOperationDetailLogLimit: Int = 10,
        fileListFontSize: Int = FileListFontSize.standard,
        appLanguage: AppLanguage = .system,
        returnKeyBehavior: ReturnKeyBehavior = .openSelectedDirectory,
        incrementalSearchMatchMode: IncrementalSearchMatchMode = .prefix,
        previewPanePosition: PreviewPanePosition = .right,
        leftStartupPathMode: StartupPathMode = .previous,
        rightStartupPathMode: StartupPathMode = .previous,
        leftStartupPath: String = "",
        rightStartupPath: String = "",
        jumpPathEntries: [JumpPathEntry] = [],
        keyBindingSet: KeyBindingSet = .default,
        displayThemeSet: DisplayThemeSet = DisplayThemeSet(),
        fileTypeAssociations: [FileTypeAssociation] = [],
        fileTypeColorScope: FileTypeColorScope = .fileName
    ) {
        self.tabs = tabs
        self.selectedTabIndex = tabs.indices.contains(selectedTabIndex) ? selectedTabIndex : 0
        self.focusedItemIndex = focusedItemIndex
        self.focusArea = focusArea
        self.showsHiddenFiles = showsHiddenFiles
        self.showsPreviewPane = showsPreviewPane
        self.usesAlternatingRowBackgrounds = usesAlternatingRowBackgrounds
        self.showsFileIcons = showsFileIcons
        self.showsFileTagColors = showsFileTagColors
        self.showsFileExtensionsSeparately = showsFileExtensionsSeparately
        self.showsMultiStrokeKeyCandidates = showsMultiStrokeKeyCandidates
        self.movesCursorAfterMarking = movesCursorAfterMarking
        self.movesToCreatedFolder = movesToCreatedFolder
        self.selectsPreviousDirectoryAfterMovingToParent = selectsPreviousDirectoryAfterMovingToParent
        self.confirmsBeforeCopy = confirmsBeforeCopy
        self.confirmsBeforeMove = confirmsBeforeMove
        self.confirmsBeforeTrash = confirmsBeforeTrash
        self.confirmsBeforeQuit = confirmsBeforeQuit
        self.allowsExternalFileDrag = allowsExternalFileDrag
        self.fileOperationDetailLogLimit = Self.normalizedNonNegativeInteger(fileOperationDetailLogLimit)
        self.fileListFontSize = FileListFontSize.normalized(fileListFontSize)
        self.appLanguage = appLanguage
        self.returnKeyBehavior = returnKeyBehavior
        self.incrementalSearchMatchMode = incrementalSearchMatchMode
        self.previewPanePosition = previewPanePosition
        self.leftStartupPathMode = leftStartupPathMode
        self.rightStartupPathMode = rightStartupPathMode
        self.leftStartupPath = Self.normalizedOptionalPath(leftStartupPath)
        self.rightStartupPath = Self.normalizedOptionalPath(rightStartupPath)
        self.jumpPathEntries = jumpPathEntries
        self.keyBindingSet = keyBindingSet
        self.displayThemeSet = displayThemeSet
        self.fileTypeAssociations = fileTypeAssociations
        self.fileTypeColorScope = fileTypeColorScope
        clampFocusedItemIndex()
    }

    public var selectedTab: SettingsTab? {
        guard tabs.indices.contains(selectedTabIndex) else {
            return nil
        }

        return tabs[selectedTabIndex]
    }

    public mutating func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }

        selectedTabIndex = index
        focusedItemIndex = 0
        clampFocusedItemIndex()
    }

    public mutating func moveTabSelection(by delta: Int) {
        guard !tabs.isEmpty else {
            selectedTabIndex = 0
            focusedItemIndex = 0
            return
        }

        selectTab(at: max(0, min(tabs.count - 1, selectedTabIndex + delta)))
    }

    public mutating func moveItemFocus(by delta: Int) {
        guard let itemCount = selectedTab?.items.count, itemCount > 0 else {
            focusedItemIndex = 0
            return
        }

        if delta < 0, focusedItemIndex == 0 {
            focusArea = .tabs
            return
        }

        focusedItemIndex = max(0, min(itemCount - 1, focusedItemIndex + delta))
        focusArea = .items
    }

    public mutating func focusItem(at index: Int) {
        guard let itemCount = selectedTab?.items.count,
              index >= 0,
              index < itemCount else {
            return
        }

        focusedItemIndex = index
        focusArea = .items
    }

    public mutating func moveJumpPathFocus(by delta: Int) {
        guard !jumpPathEntries.isEmpty else {
            focusedItemIndex = 0
            return
        }

        if delta < 0, focusedItemIndex == 0 {
            focusArea = .tabs
            return
        }

        focusedItemIndex = max(0, min(jumpPathEntries.count - 1, focusedItemIndex + delta))
        focusArea = .items
    }

    public mutating func focusJumpPath(at index: Int) {
        guard jumpPathEntries.indices.contains(index) else {
            return
        }

        focusedItemIndex = index
        focusArea = .items
    }

    public mutating func moveFileTypeAssociationFocus(by delta: Int) {
        guard !fileTypeAssociations.isEmpty else { focusedItemIndex = 0; return }
        focusedItemIndex = max(0, min(fileTypeAssociations.count - 1, focusedItemIndex + delta))
        focusArea = .items
    }

    public mutating func focusFileTypeAssociation(at index: Int) {
        guard fileTypeAssociations.indices.contains(index) else { return }
        focusedItemIndex = index
        focusArea = .items
    }

    public mutating func focusTabs() {
        focusArea = .tabs
    }

    public mutating func focusItems() {
        focusArea = .items
    }

    public mutating func toggleFocusedItem() -> SettingsToggleID? {
        guard let item = selectedTab?.items[safe: focusedItemIndex],
              let toggleID = item.toggleID else {
            return nil
        }

        toggle(toggleID)
        return toggleID
    }

    public mutating func cycleFocusedChoice() -> SettingsChoiceID? {
        guard let item = selectedTab?.items[safe: focusedItemIndex],
              let choiceID = item.choiceID else {
            return nil
        }

        cycle(choiceID)
        return choiceID
    }

    public func isToggleOn(_ toggleID: SettingsToggleID) -> Bool {
        switch toggleID {
        case .showPreviewPane:
            return showsPreviewPane
        case .showHiddenFiles:
            return showsHiddenFiles
        case .useAlternatingRowBackgrounds:
            return usesAlternatingRowBackgrounds
        case .showFileIcons:
            return showsFileIcons
        case .showFileTagColors:
            return showsFileTagColors
        case .showFileExtensionsSeparately:
            return showsFileExtensionsSeparately
        case .showMultiStrokeKeyCandidates:
            return showsMultiStrokeKeyCandidates
        case .moveCursorAfterMarking:
            return movesCursorAfterMarking
        case .moveToCreatedFolder:
            return movesToCreatedFolder
        case .selectPreviousDirectoryAfterMovingToParent:
            return selectsPreviousDirectoryAfterMovingToParent
        case .confirmBeforeCopy:
            return confirmsBeforeCopy
        case .confirmBeforeMove:
            return confirmsBeforeMove
        case .confirmBeforeTrash:
            return confirmsBeforeTrash
        case .confirmBeforeQuit:
            return confirmsBeforeQuit
        case .allowExternalFileDrag:
            return allowsExternalFileDrag
        }
    }

    public mutating func setToggle(_ toggleID: SettingsToggleID, isOn: Bool) {
        switch toggleID {
        case .showPreviewPane:
            showsPreviewPane = isOn
        case .showHiddenFiles:
            showsHiddenFiles = isOn
        case .useAlternatingRowBackgrounds:
            usesAlternatingRowBackgrounds = isOn
        case .showFileIcons:
            showsFileIcons = isOn
        case .showFileTagColors:
            showsFileTagColors = isOn
        case .showFileExtensionsSeparately:
            showsFileExtensionsSeparately = isOn
        case .showMultiStrokeKeyCandidates:
            showsMultiStrokeKeyCandidates = isOn
        case .moveCursorAfterMarking:
            movesCursorAfterMarking = isOn
        case .moveToCreatedFolder:
            movesToCreatedFolder = isOn
        case .selectPreviousDirectoryAfterMovingToParent:
            selectsPreviousDirectoryAfterMovingToParent = isOn
        case .confirmBeforeCopy:
            confirmsBeforeCopy = isOn
        case .confirmBeforeMove:
            confirmsBeforeMove = isOn
        case .confirmBeforeTrash:
            confirmsBeforeTrash = isOn
        case .confirmBeforeQuit:
            confirmsBeforeQuit = isOn
        case .allowExternalFileDrag:
            allowsExternalFileDrag = isOn
        }
    }

    public func selectedChoice(_ choiceID: SettingsChoiceID) -> SettingsChoiceValue {
        switch choiceID {
        case .previewPanePosition:
            return .previewPanePosition(previewPanePosition)
        case .appLanguage:
            return .appLanguage(appLanguage)
        case .returnKeyBehavior:
            return .returnKeyBehavior(returnKeyBehavior)
        case .incrementalSearchMatchMode:
            return .incrementalSearchMatchMode(incrementalSearchMatchMode)
        case .leftStartupPathMode:
            return .startupPathMode(leftStartupPathMode)
        case .rightStartupPathMode:
            return .startupPathMode(rightStartupPathMode)
        }
    }

    public mutating func setChoice(_ choiceID: SettingsChoiceID, to value: SettingsChoiceValue) {
        switch (choiceID, value) {
        case (.previewPanePosition, .previewPanePosition(let position)):
            previewPanePosition = position
        case (.appLanguage, .appLanguage(let language)):
            appLanguage = language
        case (.returnKeyBehavior, .returnKeyBehavior(let behavior)):
            returnKeyBehavior = behavior
        case (.incrementalSearchMatchMode, .incrementalSearchMatchMode(let mode)):
            incrementalSearchMatchMode = mode
        case (.leftStartupPathMode, .startupPathMode(let mode)):
            leftStartupPathMode = mode
        case (.rightStartupPathMode, .startupPathMode(let mode)):
            rightStartupPathMode = mode
        default:
            return
        }
    }

    public mutating func setStartupPath(_ path: String, for choiceID: SettingsChoiceID) {
        switch choiceID {
        case .leftStartupPathMode:
            leftStartupPath = Self.normalizedOptionalPath(path)
        case .rightStartupPathMode:
            rightStartupPath = Self.normalizedOptionalPath(path)
        case .appLanguage:
            return
        case .returnKeyBehavior:
            return
        case .incrementalSearchMatchMode:
            return
        case .previewPanePosition:
            return
        }
    }

    public func numericValue(_ numericID: SettingsNumericID) -> Int {
        switch numericID {
        case .fileOperationDetailLogLimit:
            return fileOperationDetailLogLimit
        case .fileListFontSize:
            return fileListFontSize
        }
    }

    public mutating func setNumericValue(_ value: Int, for numericID: SettingsNumericID) {
        switch numericID {
        case .fileOperationDetailLogLimit:
            fileOperationDetailLogLimit = Self.normalizedNonNegativeInteger(value)
        case .fileListFontSize:
            fileListFontSize = FileListFontSize.normalized(value)
        }
    }

    public mutating func setJumpPathEntries(_ entries: [JumpPathEntry]) {
        jumpPathEntries = entries
    }

    @discardableResult
    public mutating func addJumpPath(displayName: String = "", path: String) -> Bool {
        guard !containsJumpPath(path) else {
            return false
        }

        jumpPathEntries.append(JumpPathEntry(displayName: displayName, path: path))
        return true
    }

    public func containsJumpPath(_ path: String) -> Bool {
        let normalizedPath = JumpPathEntry.normalizedPath(path)
        return jumpPathEntries.contains { $0.normalizedPath == normalizedPath }
    }

    public mutating func updateJumpPath(at index: Int, displayName: String, path: String) {
        guard jumpPathEntries.indices.contains(index) else {
            return
        }

        jumpPathEntries[index] = JumpPathEntry(displayName: displayName, path: path)
    }

    public mutating func removeJumpPath(at index: Int) {
        guard jumpPathEntries.indices.contains(index) else {
            return
        }

        jumpPathEntries.remove(at: index)
    }

    public mutating func moveJumpPath(at index: Int, by delta: Int) {
        guard jumpPathEntries.indices.contains(index), delta != 0 else {
            return
        }

        let destinationIndex = max(0, min(jumpPathEntries.count - 1, index + delta))
        guard destinationIndex != index else {
            return
        }

        let entry = jumpPathEntries.remove(at: index)
        jumpPathEntries.insert(entry, at: destinationIndex)
        focusedItemIndex = destinationIndex
        focusArea = .items
    }

    public mutating func addKeyBindingSequence(_ sequence: KeyBindingSequence, to commandID: CommandID) {
        keyBindingSet.addSequence(sequence, to: commandID)
    }

    public mutating func setKeyBindingSet(_ keyBindingSet: KeyBindingSet) {
        self.keyBindingSet = keyBindingSet
    }

    public mutating func setDisplayThemeSet(_ displayThemeSet: DisplayThemeSet) {
        self.displayThemeSet = displayThemeSet
    }

    public mutating func setFileTypeAssociations(_ associations: [FileTypeAssociation]) {
        fileTypeAssociations = associations
    }

    public mutating func setFileTypeColorScope(_ scope: FileTypeColorScope) {
        fileTypeColorScope = scope
    }

    public mutating func addFileTypeAssociation(_ association: FileTypeAssociation) {
        fileTypeAssociations.append(association)
    }

    public mutating func updateFileTypeAssociation(at index: Int, with association: FileTypeAssociation) {
        guard fileTypeAssociations.indices.contains(index) else { return }
        fileTypeAssociations[index] = association
    }

    public mutating func removeFileTypeAssociation(at index: Int) {
        guard fileTypeAssociations.indices.contains(index) else { return }
        fileTypeAssociations.remove(at: index)
    }

    public mutating func removeKeyBindingSequence(at index: Int, from commandID: CommandID) {
        keyBindingSet.removeSequence(at: index, from: commandID)
    }

    public mutating func resetKeyBindingToDefault(_ commandID: CommandID) {
        keyBindingSet.resetCommandToDefault(commandID)
    }

    public mutating func resetAllKeyBindingsToDefault() {
        keyBindingSet.resetToDefault()
    }

    public mutating func selectDisplayTheme(id: String) {
        displayThemeSet.selectTheme(id: id)
    }

    public mutating func setDisplayColorPair(_ pair: DisplayColorPair, for role: DisplayColorRole) {
        var theme = displayThemeSet.selectedTheme
        theme.setColorPair(pair, for: role)
        displayThemeSet.updateSelectedTheme(theme)
    }

    @discardableResult
    public mutating func addCurrentDisplayTheme(named name: String) -> DisplayTheme {
        displayThemeSet.addThemeFromCurrent(named: name)
    }

    @discardableResult
    public mutating func deleteCurrentDisplayTheme() -> Bool {
        displayThemeSet.deleteSelectedTheme()
    }

    private mutating func toggle(_ toggleID: SettingsToggleID) {
        switch toggleID {
        case .showPreviewPane:
            showsPreviewPane.toggle()
        case .showHiddenFiles:
            showsHiddenFiles.toggle()
        case .useAlternatingRowBackgrounds:
            usesAlternatingRowBackgrounds.toggle()
        case .showFileIcons:
            showsFileIcons.toggle()
        case .showFileTagColors:
            showsFileTagColors.toggle()
        case .showFileExtensionsSeparately:
            showsFileExtensionsSeparately.toggle()
        case .showMultiStrokeKeyCandidates:
            showsMultiStrokeKeyCandidates.toggle()
        case .moveCursorAfterMarking:
            movesCursorAfterMarking.toggle()
        case .moveToCreatedFolder:
            movesToCreatedFolder.toggle()
        case .selectPreviousDirectoryAfterMovingToParent:
            selectsPreviousDirectoryAfterMovingToParent.toggle()
        case .confirmBeforeCopy:
            confirmsBeforeCopy.toggle()
        case .confirmBeforeMove:
            confirmsBeforeMove.toggle()
        case .confirmBeforeTrash:
            confirmsBeforeTrash.toggle()
        case .confirmBeforeQuit:
            confirmsBeforeQuit.toggle()
        case .allowExternalFileDrag:
            allowsExternalFileDrag.toggle()
        }
    }

    private mutating func cycle(_ choiceID: SettingsChoiceID) {
        switch choiceID {
        case .previewPanePosition:
            previewPanePosition = previewPanePosition == .right ? .left : .right
        case .appLanguage:
            let values = AppLanguage.allCases
            guard let index = values.firstIndex(of: appLanguage) else {
                appLanguage = .system
                return
            }
            appLanguage = values[(index + 1) % values.count]
        case .returnKeyBehavior:
            returnKeyBehavior = returnKeyBehavior.next
        case .incrementalSearchMatchMode:
            incrementalSearchMatchMode = incrementalSearchMatchMode.next
        case .leftStartupPathMode:
            leftStartupPathMode = leftStartupPathMode.next
        case .rightStartupPathMode:
            rightStartupPathMode = rightStartupPathMode.next
        }
    }

    private mutating func clampFocusedItemIndex() {
        guard let itemCount = selectedTab?.items.count, itemCount > 0 else {
            focusedItemIndex = 0
            return
        }

        focusedItemIndex = max(0, min(itemCount - 1, focusedItemIndex))
    }

    private static func normalizedOptionalPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return ""
        }

        return JumpPathEntry.normalizedPath(trimmedPath)
    }

    private static func normalizedNonNegativeInteger(_ value: Int) -> Int {
        max(0, value)
    }
}

public struct AppSettings: Codable, Equatable {
    public static let previewPaneWidthRatioRange: ClosedRange<Double> = 0.2...0.55
    public static let defaultPreviewPaneWidthRatio = 0.32

    public var showsHiddenFiles: Bool
    public var showsPreviewPane: Bool
    public var usesAlternatingRowBackgrounds: Bool
    public var showsFileIcons: Bool
    public var showsFileTagColors: Bool
    public var showsFileExtensionsSeparately: Bool
    public var showsMultiStrokeKeyCandidates: Bool
    public var movesCursorAfterMarking: Bool
    public var movesToCreatedFolder: Bool
    public var selectsPreviousDirectoryAfterMovingToParent: Bool
    public var confirmsBeforeCopy: Bool
    public var confirmsBeforeMove: Bool
    public var confirmsBeforeTrash: Bool
    public var confirmsBeforeQuit: Bool
    public var allowsExternalFileDrag: Bool
    public var fileOperationDetailLogLimit: Int
    public var fileListFontSize: Int
    public var appLanguage: AppLanguage
    public var returnKeyBehavior: ReturnKeyBehavior
    public var incrementalSearchMatchMode: IncrementalSearchMatchMode
    public var previewPanePosition: PreviewPanePosition
    public var previewPaneWidthRatio: Double
    public var leftStartupPathMode: StartupPathMode
    public var rightStartupPathMode: StartupPathMode
    public var leftStartupPath: String
    public var rightStartupPath: String
    public var jumpPathEntries: [JumpPathEntry]
    public var leftPanePath: String
    public var rightPanePath: String
    public var leftPaneNavigationHistory: NavigationHistory
    public var rightPaneNavigationHistory: NavigationHistory
    public var filePatternHistory: FilePatternHistory
    public var leftPaneSortDescriptor: FileSortDescriptor
    public var rightPaneSortDescriptor: FileSortDescriptor
    public var keyBindingSet: KeyBindingSet
    public var displayThemeSet: DisplayThemeSet
    public var fileTypeAssociations: [FileTypeAssociation]
    public var fileTypeColorScope: FileTypeColorScope

    public init(
        showsHiddenFiles: Bool = false,
        showsPreviewPane: Bool = false,
        usesAlternatingRowBackgrounds: Bool = false,
        showsFileIcons: Bool = true,
        showsFileTagColors: Bool = true,
        showsFileExtensionsSeparately: Bool = true,
        showsMultiStrokeKeyCandidates: Bool = true,
        movesCursorAfterMarking: Bool = true,
        movesToCreatedFolder: Bool = true,
        selectsPreviousDirectoryAfterMovingToParent: Bool = true,
        confirmsBeforeCopy: Bool = true,
        confirmsBeforeMove: Bool = true,
        confirmsBeforeTrash: Bool = true,
        confirmsBeforeQuit: Bool = true,
        allowsExternalFileDrag: Bool = false,
        fileOperationDetailLogLimit: Int = 10,
        fileListFontSize: Int = FileListFontSize.standard,
        appLanguage: AppLanguage = .system,
        returnKeyBehavior: ReturnKeyBehavior = .openSelectedDirectory,
        incrementalSearchMatchMode: IncrementalSearchMatchMode = .prefix,
        previewPanePosition: PreviewPanePosition = .right,
        previewPaneWidthRatio: Double = AppSettings.defaultPreviewPaneWidthRatio,
        leftStartupPathMode: StartupPathMode = .previous,
        rightStartupPathMode: StartupPathMode = .previous,
        leftStartupPath: String = "",
        rightStartupPath: String = "",
        jumpPathEntries: [JumpPathEntry] = [],
        leftPanePath: String,
        rightPanePath: String,
        leftPaneNavigationHistory: NavigationHistory = NavigationHistory(),
        rightPaneNavigationHistory: NavigationHistory = NavigationHistory(),
        filePatternHistory: FilePatternHistory = FilePatternHistory(),
        leftPaneSortDescriptor: FileSortDescriptor = .default,
        rightPaneSortDescriptor: FileSortDescriptor = .default,
        keyBindingSet: KeyBindingSet = .default,
        displayThemeSet: DisplayThemeSet = DisplayThemeSet(),
        fileTypeAssociations: [FileTypeAssociation] = [],
        fileTypeColorScope: FileTypeColorScope = .fileName
    ) {
        self.showsHiddenFiles = showsHiddenFiles
        self.showsPreviewPane = showsPreviewPane
        self.usesAlternatingRowBackgrounds = usesAlternatingRowBackgrounds
        self.showsFileIcons = showsFileIcons
        self.showsFileTagColors = showsFileTagColors
        self.showsFileExtensionsSeparately = showsFileExtensionsSeparately
        self.showsMultiStrokeKeyCandidates = showsMultiStrokeKeyCandidates
        self.movesCursorAfterMarking = movesCursorAfterMarking
        self.movesToCreatedFolder = movesToCreatedFolder
        self.selectsPreviousDirectoryAfterMovingToParent = selectsPreviousDirectoryAfterMovingToParent
        self.confirmsBeforeCopy = confirmsBeforeCopy
        self.confirmsBeforeMove = confirmsBeforeMove
        self.confirmsBeforeTrash = confirmsBeforeTrash
        self.confirmsBeforeQuit = confirmsBeforeQuit
        self.allowsExternalFileDrag = allowsExternalFileDrag
        self.fileOperationDetailLogLimit = Self.normalizedNonNegativeInteger(fileOperationDetailLogLimit)
        self.fileListFontSize = FileListFontSize.normalized(fileListFontSize)
        self.appLanguage = appLanguage
        self.returnKeyBehavior = returnKeyBehavior
        self.incrementalSearchMatchMode = incrementalSearchMatchMode
        self.previewPanePosition = previewPanePosition
        self.previewPaneWidthRatio = Self.normalizedPreviewPaneWidthRatio(previewPaneWidthRatio)
        self.leftStartupPathMode = leftStartupPathMode
        self.rightStartupPathMode = rightStartupPathMode
        self.leftStartupPath = Self.normalizedOptionalPath(leftStartupPath)
        self.rightStartupPath = Self.normalizedOptionalPath(rightStartupPath)
        self.jumpPathEntries = jumpPathEntries
        self.leftPanePath = JumpPathEntry.normalizedPath(leftPanePath)
        self.rightPanePath = JumpPathEntry.normalizedPath(rightPanePath)
        self.leftPaneNavigationHistory = leftPaneNavigationHistory.prepared(for: URL(
            fileURLWithPath: self.leftPanePath,
            isDirectory: true
        ))
        self.rightPaneNavigationHistory = rightPaneNavigationHistory.prepared(for: URL(
            fileURLWithPath: self.rightPanePath,
            isDirectory: true
        ))
        self.filePatternHistory = filePatternHistory
        self.leftPaneSortDescriptor = leftPaneSortDescriptor
        self.rightPaneSortDescriptor = rightPaneSortDescriptor
        self.keyBindingSet = keyBindingSet
        self.displayThemeSet = displayThemeSet
        self.fileTypeAssociations = fileTypeAssociations
        self.fileTypeColorScope = fileTypeColorScope
    }

    public init(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) {
        self.init(
            leftPanePath: homeDirectory.path,
            rightPanePath: homeDirectory.path
        )
    }

    public var settingsState: SettingsState {
        SettingsState(
            showsHiddenFiles: showsHiddenFiles,
            showsPreviewPane: showsPreviewPane,
            usesAlternatingRowBackgrounds: usesAlternatingRowBackgrounds,
            showsFileIcons: showsFileIcons,
            showsFileTagColors: showsFileTagColors,
            showsFileExtensionsSeparately: showsFileExtensionsSeparately,
            showsMultiStrokeKeyCandidates: showsMultiStrokeKeyCandidates,
            movesCursorAfterMarking: movesCursorAfterMarking,
            movesToCreatedFolder: movesToCreatedFolder,
            selectsPreviousDirectoryAfterMovingToParent: selectsPreviousDirectoryAfterMovingToParent,
            confirmsBeforeCopy: confirmsBeforeCopy,
            confirmsBeforeMove: confirmsBeforeMove,
            confirmsBeforeTrash: confirmsBeforeTrash,
            confirmsBeforeQuit: confirmsBeforeQuit,
            allowsExternalFileDrag: allowsExternalFileDrag,
            fileOperationDetailLogLimit: fileOperationDetailLogLimit,
            fileListFontSize: fileListFontSize,
            appLanguage: appLanguage,
            returnKeyBehavior: returnKeyBehavior,
            incrementalSearchMatchMode: incrementalSearchMatchMode,
            previewPanePosition: previewPanePosition,
            leftStartupPathMode: leftStartupPathMode,
            rightStartupPathMode: rightStartupPathMode,
            leftStartupPath: leftStartupPath,
            rightStartupPath: rightStartupPath,
            jumpPathEntries: jumpPathEntries,
            keyBindingSet: keyBindingSet,
            displayThemeSet: displayThemeSet,
            fileTypeAssociations: fileTypeAssociations,
            fileTypeColorScope: fileTypeColorScope
        )
    }

    public var leftPaneDirectoryURL: URL {
        URL(fileURLWithPath: effectiveLeftPanePath, isDirectory: true)
    }

    public var rightPaneDirectoryURL: URL {
        URL(fileURLWithPath: effectiveRightPanePath, isDirectory: true)
    }

    public var effectiveLeftPanePath: String {
        effectiveStartupPath(mode: leftStartupPathMode, specifiedPath: leftStartupPath, previousPath: leftPanePath)
    }

    public var effectiveRightPanePath: String {
        effectiveStartupPath(mode: rightStartupPathMode, specifiedPath: rightStartupPath, previousPath: rightPanePath)
    }

    public mutating func applySettingsState(_ state: SettingsState) {
        showsHiddenFiles = state.showsHiddenFiles
        showsPreviewPane = state.showsPreviewPane
        usesAlternatingRowBackgrounds = state.usesAlternatingRowBackgrounds
        showsFileIcons = state.showsFileIcons
        showsFileTagColors = state.showsFileTagColors
        showsFileExtensionsSeparately = state.showsFileExtensionsSeparately
        showsMultiStrokeKeyCandidates = state.showsMultiStrokeKeyCandidates
        movesCursorAfterMarking = state.movesCursorAfterMarking
        movesToCreatedFolder = state.movesToCreatedFolder
        selectsPreviousDirectoryAfterMovingToParent = state.selectsPreviousDirectoryAfterMovingToParent
        confirmsBeforeCopy = state.confirmsBeforeCopy
        confirmsBeforeMove = state.confirmsBeforeMove
        confirmsBeforeTrash = state.confirmsBeforeTrash
        confirmsBeforeQuit = state.confirmsBeforeQuit
        allowsExternalFileDrag = state.allowsExternalFileDrag
        fileOperationDetailLogLimit = Self.normalizedNonNegativeInteger(state.fileOperationDetailLogLimit)
        fileListFontSize = FileListFontSize.normalized(state.fileListFontSize)
        appLanguage = state.appLanguage
        returnKeyBehavior = state.returnKeyBehavior
        incrementalSearchMatchMode = state.incrementalSearchMatchMode
        previewPanePosition = state.previewPanePosition
        leftStartupPathMode = state.leftStartupPathMode
        rightStartupPathMode = state.rightStartupPathMode
        leftStartupPath = Self.normalizedOptionalPath(state.leftStartupPath)
        rightStartupPath = Self.normalizedOptionalPath(state.rightStartupPath)
        jumpPathEntries = state.jumpPathEntries
        keyBindingSet = state.keyBindingSet
        displayThemeSet = state.displayThemeSet
        fileTypeAssociations = state.fileTypeAssociations
        fileTypeColorScope = state.fileTypeColorScope
    }

    public mutating func setPanePaths(left: String, right: String) {
        leftPanePath = JumpPathEntry.normalizedPath(left)
        rightPanePath = JumpPathEntry.normalizedPath(right)
    }

    public mutating func setPaneNavigationHistories(left: NavigationHistory, right: NavigationHistory) {
        leftPaneNavigationHistory = left
        rightPaneNavigationHistory = right
    }

    public mutating func setPaneSortDescriptors(left: FileSortDescriptor, right: FileSortDescriptor) {
        leftPaneSortDescriptor = left
        rightPaneSortDescriptor = right
    }

    private func effectiveStartupPath(
        mode: StartupPathMode,
        specifiedPath: String,
        previousPath: String
    ) -> String {
        switch mode {
        case .previous:
            return previousPath
        case .specified:
            return specifiedPath.isEmpty ? previousPath : specifiedPath
        }
    }

    private static func normalizedOptionalPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return ""
        }

        return JumpPathEntry.normalizedPath(trimmedPath)
    }

    private static func normalizedNonNegativeInteger(_ value: Int) -> Int {
        max(0, value)
    }

    public static func normalizedPreviewPaneWidthRatio(_ value: Double) -> Double {
        min(previewPaneWidthRatioRange.upperBound, max(previewPaneWidthRatioRange.lowerBound, value))
    }
}

public extension SettingsState {
    static let defaultTabs: [SettingsTab] = [
        SettingsTab(title: "General", localizationKey: "settings.tab.general", items: [
            SettingsItem(
                title: "Startup path (left)",
                localizationKey: "settings.item.leftStartupPath",
                choiceID: .leftStartupPathMode
            ),
            SettingsItem(
                title: "Startup path (right)",
                localizationKey: "settings.item.rightStartupPath",
                choiceID: .rightStartupPathMode
            ),
            SettingsItem(
                title: "Return key behavior",
                localizationKey: "settings.item.returnKeyBehavior",
                choiceID: .returnKeyBehavior
            ),
            SettingsItem(
                title: "Incremental search",
                localizationKey: "settings.item.incrementalSearchMatchMode",
                choiceID: .incrementalSearchMatchMode
            ),
            SettingsItem(
                title: "Show preview pane",
                localizationKey: "settings.item.showPreviewPane",
                toggleID: .showPreviewPane
            ),
            SettingsItem(
                title: "Preview pane position",
                localizationKey: "settings.item.previewPanePosition",
                choiceID: .previewPanePosition
            ),
            SettingsItem(
                title: "Show hidden files",
                localizationKey: "settings.item.showHiddenFiles",
                toggleID: .showHiddenFiles
            ),
            SettingsItem(
                title: "Use alternating row backgrounds",
                localizationKey: "settings.item.useAlternatingRowBackgrounds",
                toggleID: .useAlternatingRowBackgrounds
            ),
            SettingsItem(
                title: "Show file icons",
                localizationKey: "settings.item.showFileIcons",
                toggleID: .showFileIcons
            ),
            SettingsItem(
                title: "Show file tag colors",
                localizationKey: "settings.item.showFileTagColors",
                toggleID: .showFileTagColors
            ),
            SettingsItem(
                title: "Show file extensions separately",
                localizationKey: "settings.item.showFileExtensionsSeparately",
                toggleID: .showFileExtensionsSeparately
            ),
            SettingsItem(
                title: "Show multi-stroke key candidates",
                localizationKey: "settings.item.showMultiStrokeKeyCandidates",
                toggleID: .showMultiStrokeKeyCandidates
            ),
            SettingsItem(
                title: "Move cursor after marking",
                localizationKey: "settings.item.moveCursorAfterMarking",
                toggleID: .moveCursorAfterMarking
            ),
            SettingsItem(
                title: "Move to created folder",
                localizationKey: "settings.item.moveToCreatedFolder",
                toggleID: .moveToCreatedFolder
            ),
            SettingsItem(
                title: "Select previous directory after moving to parent",
                localizationKey: "settings.item.selectPreviousDirectoryAfterMovingToParent",
                toggleID: .selectPreviousDirectoryAfterMovingToParent
            ),
            SettingsItem(
                title: "Language",
                localizationKey: "settings.item.language",
                choiceID: .appLanguage
            ),
            SettingsItem(
                title: "Confirm before copying",
                localizationKey: "settings.item.confirmBeforeCopy",
                toggleID: .confirmBeforeCopy
            ),
            SettingsItem(
                title: "Confirm before moving",
                localizationKey: "settings.item.confirmBeforeMove",
                toggleID: .confirmBeforeMove
            ),
            SettingsItem(
                title: "Confirm before moving to Trash",
                localizationKey: "settings.item.confirmBeforeTrash",
                toggleID: .confirmBeforeTrash
            ),
            SettingsItem(
                title: "Confirm before quitting",
                localizationKey: "settings.item.confirmBeforeQuit",
                toggleID: .confirmBeforeQuit
            ),
            SettingsItem(
                title: "Allow dragging files to other applications",
                localizationKey: "settings.item.allowExternalFileDrag",
                toggleID: .allowExternalFileDrag
            ),
            SettingsItem(
                title: "File operation detail log count",
                localizationKey: "settings.item.fileOperationDetailLogLimit",
                numericID: .fileOperationDetailLogLimit
            ),
            SettingsItem(
                title: "File list font size",
                localizationKey: "settings.item.fileListFontSize",
                numericID: .fileListFontSize
            )
        ]),
        SettingsTab(title: "Keybindings", localizationKey: "settings.tab.keybindings", items: CommandID.allCases.map {
            SettingsItem(title: "\($0.category.rawValue): \($0.title)", localizationKey: "command.\($0.rawValue)")
        }),
        SettingsTab(title: "Theme", localizationKey: "settings.tab.theme", items: DisplayColorRole.allCases.map {
            SettingsItem(title: $0.title, localizationKey: $0.localizationKey)
        }),
        SettingsTab(title: "Bookmarks", localizationKey: "settings.tab.bookmarks", items: [
        ]),
        SettingsTab(title: "File Types", localizationKey: "settings.tab.fileTypes", items: [])
    ]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
