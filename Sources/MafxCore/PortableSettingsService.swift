import Foundation

public enum PortableSettingsError: LocalizedError {
    case unsupportedFormat(String)
    case unsupportedSchemaVersion(Int)
    case missingSetting(String)
    case invalidSettings(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported settings format: \(format)"
        case .unsupportedSchemaVersion(let version):
            return "Unsupported settings schema version: \(version)"
        case .missingSetting(let setting):
            return "Settings file does not contain \(setting)."
        case .invalidSettings(let reason):
            return "Invalid settings file: \(reason)"
        }
    }
}

public final class PortableSettingsJSONService {
    public static let format = "antlers-settings"
    public static let schemaVersion = 1
    private static let supportedFormats = Set([format, "mafx-settings"])

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        decoder = JSONDecoder()
    }

    public func exportData(from state: SettingsState) throws -> Data {
        let document = PortableSettingsDocument(
            format: Self.format,
            schemaVersion: Self.schemaVersion,
            settings: PortableSettingsV1(state: state)
        )
        return try encoder.encode(document)
    }

    public func writeSettings(_ state: SettingsState, to url: URL) throws {
        let data = try exportData(from: state)
        try data.write(to: url, options: .atomic)
    }

    public func importSettingsState(
        from data: Data,
        defaultState: SettingsState = SettingsState()
    ) throws -> SettingsState {
        let document = try decodedDocument(from: data)
        return try document.settings.settingsState(defaultState: defaultState)
    }

    public func importKeyBindingSet(from data: Data) throws -> KeyBindingSet {
        let document = try decodedDocument(from: data)
        guard let keyBindingSet = document.settings.keyBindingSet else {
            throw PortableSettingsError.missingSetting("keyBindingSet")
        }

        return try PortableSettingsV1.validatedKeyBindingSet(keyBindingSet)
    }

    public func importDisplayThemeSet(
        from data: Data,
        fallbackThemeSet: DisplayThemeSet = DisplayThemeSet()
    ) throws -> DisplayThemeSet {
        let document = try decodedDocument(from: data)
        guard let displayThemeSet = document.settings.displayThemeSet else {
            throw PortableSettingsError.missingSetting("displayThemeSet")
        }

        return try PortableSettingsV1.validatedDisplayThemeSet(
            displayThemeSet,
            defaultThemeSet: fallbackThemeSet
        )
    }

    public func readSettingsState(
        from url: URL,
        defaultState: SettingsState = SettingsState()
    ) throws -> SettingsState {
        let data = try Data(contentsOf: url)
        return try importSettingsState(from: data, defaultState: defaultState)
    }

    public func readKeyBindingSet(from url: URL) throws -> KeyBindingSet {
        try importKeyBindingSet(from: Data(contentsOf: url))
    }

    public func readDisplayThemeSet(
        from url: URL,
        fallbackThemeSet: DisplayThemeSet = DisplayThemeSet()
    ) throws -> DisplayThemeSet {
        try importDisplayThemeSet(from: Data(contentsOf: url), fallbackThemeSet: fallbackThemeSet)
    }

    private func decodedDocument(from data: Data) throws -> PortableSettingsDocument {
        let document = try decoder.decode(PortableSettingsDocument.self, from: data)
        guard Self.supportedFormats.contains(document.format) else {
            throw PortableSettingsError.unsupportedFormat(document.format)
        }
        guard document.schemaVersion == Self.schemaVersion else {
            throw PortableSettingsError.unsupportedSchemaVersion(document.schemaVersion)
        }

        return document
    }
}

private struct PortableSettingsDocument: Codable {
    var format: String
    var schemaVersion: Int
    var settings: PortableSettingsV1
}

private struct PortableSettingsV1: Codable {
    var showsHiddenFiles: Bool?
    var usesAlternatingRowBackgrounds: Bool?
    var showsFileIcons: Bool?
    var showsFileTagColors: Bool?
    var showsFileExtensionsSeparately: Bool?
    var showsMultiStrokeKeyCandidates: Bool?
    var movesCursorAfterMarking: Bool?
    var movesToCreatedFolder: Bool?
    var selectsPreviousDirectoryAfterMovingToParent: Bool?
    var confirmsBeforeCopy: Bool?
    var confirmsBeforeMove: Bool?
    var confirmsBeforeTrash: Bool?
    var confirmsBeforeQuit: Bool?
    var fileOperationDetailLogLimit: Int?
    var appLanguage: AppLanguage?
    var returnKeyBehavior: ReturnKeyBehavior?
    var incrementalSearchMatchMode: IncrementalSearchMatchMode?
    var leftStartupPathMode: StartupPathMode?
    var rightStartupPathMode: StartupPathMode?
    var leftStartupPath: String?
    var rightStartupPath: String?
    var jumpPathEntries: [JumpPathEntry]?
    var keyBindingSet: KeyBindingSet?
    var displayThemeSet: DisplayThemeSet?
    var fileTypeAssociations: [FileTypeAssociation]?
    var fileTypeColorScope: FileTypeColorScope?

    init(state: SettingsState) {
        showsHiddenFiles = state.showsHiddenFiles
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
        fileOperationDetailLogLimit = state.fileOperationDetailLogLimit
        appLanguage = state.appLanguage
        returnKeyBehavior = state.returnKeyBehavior
        incrementalSearchMatchMode = state.incrementalSearchMatchMode
        leftStartupPathMode = state.leftStartupPathMode
        rightStartupPathMode = state.rightStartupPathMode
        leftStartupPath = state.leftStartupPath
        rightStartupPath = state.rightStartupPath
        jumpPathEntries = state.jumpPathEntries
        keyBindingSet = state.keyBindingSet
        displayThemeSet = state.displayThemeSet
        fileTypeAssociations = state.fileTypeAssociations
        fileTypeColorScope = state.fileTypeColorScope
    }

    func settingsState(defaultState: SettingsState) throws -> SettingsState {
        SettingsState(
            showsHiddenFiles: showsHiddenFiles ?? defaultState.showsHiddenFiles,
            usesAlternatingRowBackgrounds: usesAlternatingRowBackgrounds
                ?? defaultState.usesAlternatingRowBackgrounds,
            showsFileIcons: showsFileIcons ?? defaultState.showsFileIcons,
            showsFileTagColors: showsFileTagColors ?? defaultState.showsFileTagColors,
            showsFileExtensionsSeparately: showsFileExtensionsSeparately ?? defaultState.showsFileExtensionsSeparately,
            showsMultiStrokeKeyCandidates: showsMultiStrokeKeyCandidates ?? defaultState.showsMultiStrokeKeyCandidates,
            movesCursorAfterMarking: movesCursorAfterMarking ?? defaultState.movesCursorAfterMarking,
            movesToCreatedFolder: movesToCreatedFolder ?? defaultState.movesToCreatedFolder,
            selectsPreviousDirectoryAfterMovingToParent: selectsPreviousDirectoryAfterMovingToParent
                ?? defaultState.selectsPreviousDirectoryAfterMovingToParent,
            confirmsBeforeCopy: confirmsBeforeCopy ?? defaultState.confirmsBeforeCopy,
            confirmsBeforeMove: confirmsBeforeMove ?? defaultState.confirmsBeforeMove,
            confirmsBeforeTrash: confirmsBeforeTrash ?? defaultState.confirmsBeforeTrash,
            confirmsBeforeQuit: confirmsBeforeQuit ?? defaultState.confirmsBeforeQuit,
            fileOperationDetailLogLimit: max(
                0,
                fileOperationDetailLogLimit ?? defaultState.fileOperationDetailLogLimit
            ),
            appLanguage: appLanguage ?? defaultState.appLanguage,
            returnKeyBehavior: returnKeyBehavior ?? defaultState.returnKeyBehavior,
            incrementalSearchMatchMode: incrementalSearchMatchMode ?? defaultState.incrementalSearchMatchMode,
            leftStartupPathMode: leftStartupPathMode ?? defaultState.leftStartupPathMode,
            rightStartupPathMode: rightStartupPathMode ?? defaultState.rightStartupPathMode,
            leftStartupPath: leftStartupPath ?? defaultState.leftStartupPath,
            rightStartupPath: rightStartupPath ?? defaultState.rightStartupPath,
            jumpPathEntries: try Self.validatedJumpPathEntries(jumpPathEntries ?? defaultState.jumpPathEntries),
            keyBindingSet: try Self.validatedKeyBindingSet(keyBindingSet ?? defaultState.keyBindingSet),
            displayThemeSet: try Self.validatedDisplayThemeSet(
                displayThemeSet ?? defaultState.displayThemeSet,
                defaultThemeSet: defaultState.displayThemeSet
            ),
            fileTypeAssociations: try Self.validatedFileTypeAssociations(
                fileTypeAssociations ?? defaultState.fileTypeAssociations
            ),
            fileTypeColorScope: fileTypeColorScope ?? defaultState.fileTypeColorScope
        )
    }

    private static func validatedFileTypeAssociations(_ associations: [FileTypeAssociation]) throws -> [FileTypeAssociation] {
        let validated: [FileTypeAssociation] = associations.compactMap { association in
            let extensions = FileTypeAssociation.normalizedExtensions(association.extensions)
            guard !extensions.isEmpty else { return nil }
            return FileTypeAssociation(
                id: association.id,
                extensions: extensions,
                applicationPath: association.applicationPath,
                color: association.color
            )
        }

        let duplicates = FileTypeAssociation.duplicateExtensions(in: validated)
        guard duplicates.isEmpty else {
            throw PortableSettingsError.invalidSettings(
                "fileTypeAssociations contains duplicate extensions: \(duplicates.joined(separator: ", "))"
            )
        }

        return validated
    }

    private static func validatedJumpPathEntries(_ entries: [JumpPathEntry]) throws -> [JumpPathEntry] {
        var normalizedEntries: [JumpPathEntry] = []
        var seenPaths: Set<String> = []

        for entry in entries {
            let trimmedPath = entry.path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPath.isEmpty else {
                throw PortableSettingsError.invalidSettings("Jump path must not be empty.")
            }

            let normalizedPath = JumpPathEntry.normalizedPath(trimmedPath)
            guard !seenPaths.contains(normalizedPath) else {
                continue
            }

            seenPaths.insert(normalizedPath)
            normalizedEntries.append(JumpPathEntry(displayName: entry.displayName, path: normalizedPath))
        }

        return normalizedEntries
    }

    static func validatedKeyBindingSet(_ keyBindingSet: KeyBindingSet) throws -> KeyBindingSet {
        var seenEntries: Set<String> = []
        let allowedModifierMask = KeyModifiers.shift.rawValue
            | KeyModifiers.control.rawValue
            | KeyModifiers.option.rawValue
            | KeyModifiers.command.rawValue

        for entry in keyBindingSet.entries {
            let entryKey = "\(entry.context.rawValue):\(entry.commandID.rawValue)"
            guard !seenEntries.contains(entryKey) else {
                throw PortableSettingsError.invalidSettings("Duplicate key binding entry: \(entryKey)")
            }
            seenEntries.insert(entryKey)

            for sequence in entry.sequences {
                guard !sequence.strokes.isEmpty else {
                    throw PortableSettingsError.invalidSettings("Key binding sequence must not be empty.")
                }

                for stroke in sequence.strokes {
                    guard !stroke.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw PortableSettingsError.invalidSettings("Key stroke must not be empty.")
                    }

                    guard stroke.modifiers.rawValue & ~allowedModifierMask == 0 else {
                        throw PortableSettingsError.invalidSettings("Key stroke contains unsupported modifiers.")
                    }
                }
            }
        }

        return keyBindingSet.fillingMissingDefaultEntries().reservingUnmodifiedReturn()
    }

    static func validatedDisplayThemeSet(
        _ themeSet: DisplayThemeSet,
        defaultThemeSet: DisplayThemeSet
    ) throws -> DisplayThemeSet {
        var seenThemeIDs = Set(DisplayThemeSet.protectedThemeIDs)
        var customThemes: [DisplayTheme] = []

        for theme in themeSet.themes where !DisplayThemeSet.protectedThemeIDs.contains(theme.id) {
            let trimmedID = theme.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty else {
                throw PortableSettingsError.invalidSettings("Theme id must not be empty.")
            }
            guard !seenThemeIDs.contains(theme.id) else {
                throw PortableSettingsError.invalidSettings("Duplicate theme id: \(theme.id)")
            }

            seenThemeIDs.insert(theme.id)
            customThemes.append(theme)
        }

        let themes = DisplayTheme.defaultThemes + customThemes
        let fallbackSelectedThemeID = themes.contains { $0.id == defaultThemeSet.selectedThemeID }
            ? defaultThemeSet.selectedThemeID
            : themes[0].id
        let selectedThemeID = themes.contains { $0.id == themeSet.selectedThemeID }
            ? themeSet.selectedThemeID
            : fallbackSelectedThemeID

        return DisplayThemeSet(selectedThemeID: selectedThemeID, themes: themes)
    }
}
