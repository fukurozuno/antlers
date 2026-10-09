import Foundation

public protocol SettingsRepository {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

public final class UserDefaultsSettingsRepository: SettingsRepository {
    private enum Key {
        static let showsHiddenFiles = "settings.showsHiddenFiles"
        static let incrementalSearchPriority = "settings.incrementalSearchPriority"
        static let showsCommandPaletteButton = "settings.showsCommandPaletteButton"
        static let showsPreviewPane = "settings.showsPreviewPane"
        static let previewPanePosition = "settings.previewPanePosition"
        static let previewPaneWidthRatio = "settings.previewPaneWidthRatio"
        static let usesAlternatingRowBackgrounds = "settings.usesAlternatingRowBackgrounds"
        static let showsFileIcons = "settings.showsFileIcons"
        static let showsFileTagColors = "settings.showsFileTagColors"
        static let showsFileExtensionsSeparately = "settings.showsFileExtensionsSeparately"
        static let showsMultiStrokeKeyCandidates = "settings.showsMultiStrokeKeyCandidates"
        static let movesCursorAfterMarking = "settings.movesCursorAfterMarking"
        static let movesToCreatedFolder = "settings.movesToCreatedFolder"
        static let selectsPreviousDirectoryAfterMovingToParent = "settings.selectsPreviousDirectoryAfterMovingToParent"
        static let confirmsBeforeCopy = "settings.confirmsBeforeCopy"
        static let confirmsBeforeMove = "settings.confirmsBeforeMove"
        static let confirmsBeforeTrash = "settings.confirmsBeforeTrash"
        static let confirmsBeforeQuit = "settings.confirmsBeforeQuit"
        static let allowsExternalFileDrag = "settings.allowsExternalFileDrag"
        static let treatZipAsDirectory = "settings.treatZipAsDirectory"
        static let fileOperationDetailLogLimit = "settings.fileOperationDetailLogLimit"
        static let fileListFontSize = "settings.fileListFontSize"
        static let appLanguage = "settings.appLanguage"
        static let returnKeyBehavior = "settings.returnKeyBehavior"
        static let incrementalSearchMatchMode = "settings.incrementalSearchMatchMode"
        static let leftStartupPathMode = "settings.startupPath.left.mode"
        static let rightStartupPathMode = "settings.startupPath.right.mode"
        static let leftStartupPath = "settings.startupPath.left.path"
        static let rightStartupPath = "settings.startupPath.right.path"
        static let jumpPathEntries = "settings.jumpPathEntries"
        static let leftPanePath = "pane.left.currentPath"
        static let rightPanePath = "pane.right.currentPath"
        static let leftPaneNavigationHistory = "pane.left.navigationHistory"
        static let rightPaneNavigationHistory = "pane.right.navigationHistory"
        static let filePatternHistory = "settings.filePatternHistory"
        static let leftPaneSortDescriptor = "pane.left.sortDescriptor"
        static let rightPaneSortDescriptor = "pane.right.sortDescriptor"
        static let keyBindingSet = "settings.keyBindingSet"
        static let displayThemeSet = "settings.displayThemeSet"
        static let fileTypeAssociations = "settings.fileTypeAssociations"
        static let fileTypeColorScope = "settings.fileTypeColorScope"
    }

    private let userDefaults: UserDefaults
    private let defaultSettings: AppSettings

    public init(
        userDefaults: UserDefaults = .standard,
        defaultSettings: AppSettings = AppSettings()
    ) {
        self.userDefaults = userDefaults
        self.defaultSettings = defaultSettings
    }

    public func load() -> AppSettings {
        AppSettings(
            showsHiddenFiles: bool(forKey: Key.showsHiddenFiles, defaultValue: defaultSettings.showsHiddenFiles),
            incrementalSearchPriority: bool(
                forKey: Key.incrementalSearchPriority,
                defaultValue: defaultSettings.incrementalSearchPriority
            ),
            showsCommandPaletteButton: bool(
                forKey: Key.showsCommandPaletteButton,
                defaultValue: defaultSettings.showsCommandPaletteButton
            ),
            showsPreviewPane: bool(forKey: Key.showsPreviewPane, defaultValue: defaultSettings.showsPreviewPane),
            usesAlternatingRowBackgrounds: bool(
                forKey: Key.usesAlternatingRowBackgrounds,
                defaultValue: defaultSettings.usesAlternatingRowBackgrounds
            ),
            showsFileIcons: bool(forKey: Key.showsFileIcons, defaultValue: defaultSettings.showsFileIcons),
            showsFileTagColors: bool(forKey: Key.showsFileTagColors, defaultValue: defaultSettings.showsFileTagColors),
            showsFileExtensionsSeparately: bool(
                forKey: Key.showsFileExtensionsSeparately,
                defaultValue: defaultSettings.showsFileExtensionsSeparately
            ),
            showsMultiStrokeKeyCandidates: bool(
                forKey: Key.showsMultiStrokeKeyCandidates,
                defaultValue: defaultSettings.showsMultiStrokeKeyCandidates
            ),
            movesCursorAfterMarking: bool(
                forKey: Key.movesCursorAfterMarking,
                defaultValue: defaultSettings.movesCursorAfterMarking
            ),
            movesToCreatedFolder: bool(
                forKey: Key.movesToCreatedFolder,
                defaultValue: defaultSettings.movesToCreatedFolder
            ),
            selectsPreviousDirectoryAfterMovingToParent: bool(
                forKey: Key.selectsPreviousDirectoryAfterMovingToParent,
                defaultValue: defaultSettings.selectsPreviousDirectoryAfterMovingToParent
            ),
            confirmsBeforeCopy: bool(
                forKey: Key.confirmsBeforeCopy,
                defaultValue: defaultSettings.confirmsBeforeCopy
            ),
            confirmsBeforeMove: bool(
                forKey: Key.confirmsBeforeMove,
                defaultValue: defaultSettings.confirmsBeforeMove
            ),
            confirmsBeforeTrash: bool(
                forKey: Key.confirmsBeforeTrash,
                defaultValue: defaultSettings.confirmsBeforeTrash
            ),
            confirmsBeforeQuit: bool(
                forKey: Key.confirmsBeforeQuit,
                defaultValue: defaultSettings.confirmsBeforeQuit
            ),
            allowsExternalFileDrag: bool(
                forKey: Key.allowsExternalFileDrag,
                defaultValue: defaultSettings.allowsExternalFileDrag
            ),
            treatZipAsDirectory: bool(
                forKey: Key.treatZipAsDirectory,
                defaultValue: defaultSettings.treatZipAsDirectory
            ),
            fileOperationDetailLogLimit: int(
                forKey: Key.fileOperationDetailLogLimit,
                defaultValue: defaultSettings.fileOperationDetailLogLimit
            ),
            fileListFontSize: fileListFontSize(
                forKey: Key.fileListFontSize,
                defaultValue: defaultSettings.fileListFontSize
            ),
            appLanguage: appLanguage(forKey: Key.appLanguage, defaultValue: defaultSettings.appLanguage),
            returnKeyBehavior: returnKeyBehavior(
                forKey: Key.returnKeyBehavior,
                defaultValue: defaultSettings.returnKeyBehavior
            ),
            incrementalSearchMatchMode: incrementalSearchMatchMode(
                forKey: Key.incrementalSearchMatchMode,
                defaultValue: defaultSettings.incrementalSearchMatchMode
            ),
            previewPanePosition: previewPanePosition(
                forKey: Key.previewPanePosition,
                defaultValue: defaultSettings.previewPanePosition
            ),
            previewPaneWidthRatio: previewPaneWidthRatio(
                forKey: Key.previewPaneWidthRatio,
                defaultValue: defaultSettings.previewPaneWidthRatio
            ),
            leftStartupPathMode: startupPathMode(
                forKey: Key.leftStartupPathMode,
                defaultValue: defaultSettings.leftStartupPathMode
            ),
            rightStartupPathMode: startupPathMode(
                forKey: Key.rightStartupPathMode,
                defaultValue: defaultSettings.rightStartupPathMode
            ),
            leftStartupPath: string(forKey: Key.leftStartupPath, defaultValue: defaultSettings.leftStartupPath),
            rightStartupPath: string(forKey: Key.rightStartupPath, defaultValue: defaultSettings.rightStartupPath),
            jumpPathEntries: loadJumpPathEntries(),
            leftPanePath: string(forKey: Key.leftPanePath, defaultValue: defaultSettings.leftPanePath),
            rightPanePath: string(forKey: Key.rightPanePath, defaultValue: defaultSettings.rightPanePath),
            leftPaneNavigationHistory: loadNavigationHistory(
                forKey: Key.leftPaneNavigationHistory,
                defaultValue: defaultSettings.leftPaneNavigationHistory
            ),
            rightPaneNavigationHistory: loadNavigationHistory(
                forKey: Key.rightPaneNavigationHistory,
                defaultValue: defaultSettings.rightPaneNavigationHistory
            ),
            filePatternHistory: loadFilePatternHistory(),
            leftPaneSortDescriptor: loadSortDescriptor(
                forKey: Key.leftPaneSortDescriptor,
                defaultValue: defaultSettings.leftPaneSortDescriptor
            ),
            rightPaneSortDescriptor: loadSortDescriptor(
                forKey: Key.rightPaneSortDescriptor,
                defaultValue: defaultSettings.rightPaneSortDescriptor
            ),
            keyBindingSet: loadKeyBindingSet(),
            displayThemeSet: loadDisplayThemeSet(),
            fileTypeAssociations: loadFileTypeAssociations(),
            fileTypeColorScope: fileTypeColorScope()
        )
    }

    public func save(_ settings: AppSettings) {
        userDefaults.set(settings.showsHiddenFiles, forKey: Key.showsHiddenFiles)
        userDefaults.set(settings.incrementalSearchPriority, forKey: Key.incrementalSearchPriority)
        userDefaults.set(settings.showsCommandPaletteButton, forKey: Key.showsCommandPaletteButton)
        userDefaults.set(settings.showsPreviewPane, forKey: Key.showsPreviewPane)
        userDefaults.set(settings.previewPanePosition.rawValue, forKey: Key.previewPanePosition)
        userDefaults.set(settings.previewPaneWidthRatio, forKey: Key.previewPaneWidthRatio)
        userDefaults.set(settings.usesAlternatingRowBackgrounds, forKey: Key.usesAlternatingRowBackgrounds)
        userDefaults.set(settings.showsFileIcons, forKey: Key.showsFileIcons)
        userDefaults.set(settings.showsFileTagColors, forKey: Key.showsFileTagColors)
        userDefaults.set(settings.showsFileExtensionsSeparately, forKey: Key.showsFileExtensionsSeparately)
        userDefaults.set(settings.showsMultiStrokeKeyCandidates, forKey: Key.showsMultiStrokeKeyCandidates)
        userDefaults.set(settings.movesCursorAfterMarking, forKey: Key.movesCursorAfterMarking)
        userDefaults.set(settings.movesToCreatedFolder, forKey: Key.movesToCreatedFolder)
        userDefaults.set(
            settings.selectsPreviousDirectoryAfterMovingToParent,
            forKey: Key.selectsPreviousDirectoryAfterMovingToParent
        )
        userDefaults.set(settings.confirmsBeforeCopy, forKey: Key.confirmsBeforeCopy)
        userDefaults.set(settings.confirmsBeforeMove, forKey: Key.confirmsBeforeMove)
        userDefaults.set(settings.confirmsBeforeTrash, forKey: Key.confirmsBeforeTrash)
        userDefaults.set(settings.confirmsBeforeQuit, forKey: Key.confirmsBeforeQuit)
        userDefaults.set(settings.allowsExternalFileDrag, forKey: Key.allowsExternalFileDrag)
        userDefaults.set(settings.treatZipAsDirectory, forKey: Key.treatZipAsDirectory)
        userDefaults.set(settings.fileOperationDetailLogLimit, forKey: Key.fileOperationDetailLogLimit)
        userDefaults.set(settings.fileListFontSize, forKey: Key.fileListFontSize)
        userDefaults.set(settings.appLanguage.rawValue, forKey: Key.appLanguage)
        userDefaults.set(settings.returnKeyBehavior.rawValue, forKey: Key.returnKeyBehavior)
        userDefaults.set(settings.incrementalSearchMatchMode.rawValue, forKey: Key.incrementalSearchMatchMode)
        userDefaults.set(settings.leftStartupPathMode.rawValue, forKey: Key.leftStartupPathMode)
        userDefaults.set(settings.rightStartupPathMode.rawValue, forKey: Key.rightStartupPathMode)
        userDefaults.set(settings.leftStartupPath, forKey: Key.leftStartupPath)
        userDefaults.set(settings.rightStartupPath, forKey: Key.rightStartupPath)
        userDefaults.set(settings.leftPanePath, forKey: Key.leftPanePath)
        userDefaults.set(settings.rightPanePath, forKey: Key.rightPanePath)

        if let data = try? JSONEncoder().encode(settings.jumpPathEntries) {
            userDefaults.set(data, forKey: Key.jumpPathEntries)
        }
        if let data = try? JSONEncoder().encode(settings.leftPaneNavigationHistory) {
            userDefaults.set(data, forKey: Key.leftPaneNavigationHistory)
        }
        if let data = try? JSONEncoder().encode(settings.rightPaneNavigationHistory) {
            userDefaults.set(data, forKey: Key.rightPaneNavigationHistory)
        }
        if let data = try? JSONEncoder().encode(settings.filePatternHistory) {
            userDefaults.set(data, forKey: Key.filePatternHistory)
        }
        if let data = try? JSONEncoder().encode(settings.leftPaneSortDescriptor) {
            userDefaults.set(data, forKey: Key.leftPaneSortDescriptor)
        }
        if let data = try? JSONEncoder().encode(settings.rightPaneSortDescriptor) {
            userDefaults.set(data, forKey: Key.rightPaneSortDescriptor)
        }
        if let data = try? JSONEncoder().encode(settings.keyBindingSet) {
            userDefaults.set(data, forKey: Key.keyBindingSet)
        }
        if let data = try? JSONEncoder().encode(settings.displayThemeSet) {
            userDefaults.set(data, forKey: Key.displayThemeSet)
        }
        if let data = try? JSONEncoder().encode(settings.fileTypeAssociations) {
            userDefaults.set(data, forKey: Key.fileTypeAssociations)
        }
        userDefaults.set(settings.fileTypeColorScope.rawValue, forKey: Key.fileTypeColorScope)
    }

    private func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return userDefaults.bool(forKey: key)
    }

    private func string(forKey key: String, defaultValue: String) -> String {
        guard let value = userDefaults.string(forKey: key), !value.isEmpty else {
            return defaultValue
        }

        return value
    }

    private func int(forKey key: String, defaultValue: Int) -> Int {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return max(0, userDefaults.integer(forKey: key))
    }

    private func fileListFontSize(forKey key: String, defaultValue: Int) -> Int {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return FileListFontSize.normalized(userDefaults.integer(forKey: key))
    }

    private func appLanguage(forKey key: String, defaultValue: AppLanguage) -> AppLanguage {
        guard let value = userDefaults.string(forKey: key),
              let language = AppLanguage(rawValue: value) else {
            return defaultValue
        }

        return language
    }

    private func startupPathMode(forKey key: String, defaultValue: StartupPathMode) -> StartupPathMode {
        guard let value = userDefaults.string(forKey: key),
              let mode = StartupPathMode(rawValue: value) else {
            return defaultValue
        }

        return mode
    }

    private func returnKeyBehavior(forKey key: String, defaultValue: ReturnKeyBehavior) -> ReturnKeyBehavior {
        guard let value = userDefaults.string(forKey: key),
              let behavior = ReturnKeyBehavior(rawValue: value) else {
            return defaultValue
        }

        return behavior
    }

    private func incrementalSearchMatchMode(
        forKey key: String,
        defaultValue: IncrementalSearchMatchMode
    ) -> IncrementalSearchMatchMode {
        guard let value = userDefaults.string(forKey: key),
              let mode = IncrementalSearchMatchMode(rawValue: value) else {
            return defaultValue
        }

        return mode
    }

    private func previewPanePosition(
        forKey key: String,
        defaultValue: PreviewPanePosition
    ) -> PreviewPanePosition {
        guard let value = userDefaults.string(forKey: key),
              let position = PreviewPanePosition(rawValue: value) else {
            return defaultValue
        }
        return position
    }

    private func previewPaneWidthRatio(forKey key: String, defaultValue: Double) -> Double {
        guard userDefaults.object(forKey: key) != nil else { return defaultValue }
        return AppSettings.normalizedPreviewPaneWidthRatio(userDefaults.double(forKey: key))
    }

    private func loadJumpPathEntries() -> [JumpPathEntry] {
        guard let data = userDefaults.data(forKey: Key.jumpPathEntries),
              let entries = try? JSONDecoder().decode([JumpPathEntry].self, from: data) else {
            return defaultSettings.jumpPathEntries
        }

        return entries
    }

    private func loadNavigationHistory(forKey key: String, defaultValue: NavigationHistory) -> NavigationHistory {
        guard let data = userDefaults.data(forKey: key),
              let history = try? JSONDecoder().decode(NavigationHistory.self, from: data) else {
            return defaultValue
        }

        return history
    }

    private func loadFilePatternHistory() -> FilePatternHistory {
        guard let data = userDefaults.data(forKey: Key.filePatternHistory),
              let history = try? JSONDecoder().decode(FilePatternHistory.self, from: data) else {
            return defaultSettings.filePatternHistory
        }

        return history
    }

    private func loadSortDescriptor(forKey key: String, defaultValue: FileSortDescriptor) -> FileSortDescriptor {
        guard let data = userDefaults.data(forKey: key),
              let descriptor = try? JSONDecoder().decode(FileSortDescriptor.self, from: data) else {
            return defaultValue
        }

        return descriptor
    }

    private func loadKeyBindingSet() -> KeyBindingSet {
        guard let data = userDefaults.data(forKey: Key.keyBindingSet),
              let keyBindingSet = try? JSONDecoder().decode(KeyBindingSet.self, from: data) else {
            return defaultSettings.keyBindingSet
        }

        return keyBindingSet.fillingMissingDefaultEntries().reservingUnmodifiedReturn()
    }

    private func loadDisplayThemeSet() -> DisplayThemeSet {
        guard let data = userDefaults.data(forKey: Key.displayThemeSet),
              let themeSet = try? JSONDecoder().decode(DisplayThemeSet.self, from: data) else {
            return defaultSettings.displayThemeSet
        }

        let customThemes = themeSet.themes.filter {
            !DisplayThemeSet.protectedThemeIDs.contains($0.id)
        }
        return DisplayThemeSet(
            selectedThemeID: themeSet.selectedThemeID,
            themes: DisplayTheme.defaultThemes + customThemes
        )
    }

    private func loadFileTypeAssociations() -> [FileTypeAssociation] {
        guard let data = userDefaults.data(forKey: Key.fileTypeAssociations),
              let associations = try? JSONDecoder().decode([FileTypeAssociation].self, from: data) else {
            return defaultSettings.fileTypeAssociations
        }
        return associations
    }

    private func fileTypeColorScope() -> FileTypeColorScope {
        guard let rawValue = userDefaults.string(forKey: Key.fileTypeColorScope),
              let scope = FileTypeColorScope(rawValue: rawValue) else {
            return defaultSettings.fileTypeColorScope
        }
        return scope
    }
}
