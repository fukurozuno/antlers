import AppKit
import MafxCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windowController: MainWindowController?
    private let settingsRepository: SettingsRepository
    private let windowFrameRepository: WindowFrameRepository
    private var appSettings: AppSettings
    private let storedAppSettings: AppSettings
    private let launchOptions: LaunchOptions
    private let settingsWindowController: SettingsWindowController
    private let fileSystemScope: FileSystemScope?

    override init() {
        let repository = UserDefaultsSettingsRepository()
        let loadedSettings = repository.load()
        let launchOptions = LaunchOptions.parse(arguments: Array(ProcessInfo.processInfo.arguments.dropFirst()))
        var runtimeSettings = loadedSettings
        if let appLanguage = launchOptions.appLanguage {
            runtimeSettings.appLanguage = appLanguage
        }
        if let themeID = launchOptions.themeID,
           runtimeSettings.displayThemeSet.themes.contains(where: { $0.id == themeID }) {
            runtimeSettings.displayThemeSet.selectTheme(id: themeID)
        }
        L10n.setAppLanguage(runtimeSettings.appLanguage)
        settingsRepository = repository
        windowFrameRepository = UserDefaultsWindowFrameRepository()
        appSettings = runtimeSettings
        storedAppSettings = loadedSettings
        self.launchOptions = launchOptions
        fileSystemScope = Self.fileSystemScopeFromArguments()
        settingsWindowController = SettingsWindowController(settings: runtimeSettings.settingsState)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let fileSystemScope else {
            let alert = NSAlert()
            alert.messageText = L10n.string("alert.confinedRoot.invalid.title")
            alert.informativeText = L10n.string("alert.confinedRoot.invalid.message")
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        configureMainMenu()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettingsWindow(_:)),
            name: .settingsWindowRequested,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(quitApplication(_:)),
            name: .applicationQuitRequested,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange(_:)),
            name: .settingsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(jumpPathEntriesDidChange(_:)),
            name: .jumpPathEntriesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(paneDirectoriesDidChange(_:)),
            name: .paneDirectoriesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(filePatternHistoryDidChange(_:)),
            name: .filePatternHistoryDidChange,
            object: nil
        )

        let windowController = MainWindowController(
            settings: appSettings,
            savedFrame: windowFrameRepository.load(),
            fileSystemScope: fileSystemScope,
            initialLeftPath: Self.relativeLaunchPath("--left-path", in: fileSystemScope),
            initialRightPath: Self.relativeLaunchPath("--right-path", in: fileSystemScope)
        )
        self.windowController = windowController
        windowController.window?.delegate = self

        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func fileSystemScopeFromArguments() -> FileSystemScope? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--confined-root"), arguments.indices.contains(index + 1) else {
            return .some(.unrestricted)
        }
        let rootURL = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        return FileSystemScope(confinedRootURL: rootURL)
    }

    private static func relativeLaunchPath(_ option: String, in scope: FileSystemScope) -> URL? {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: option),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1),
              let rootURL = scope.confinedRootURL else { return nil }
        return scope.relativePath(ProcessInfo.processInfo.arguments[index + 1]) ?? rootURL
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard appSettings.confirmsBeforeQuit else {
            return .terminateNow
        }

        return promptForQuitConfirmation() ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveMainWindowFrame()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        saveMainWindowFrame()
        NSApp.terminate(nil)
        return false
    }

    private func saveMainWindowFrame() {
        guard let frame = windowController?.window?.frame,
              let windowFrame = WindowFrame(
                originX: frame.origin.x,
                originY: frame.origin.y,
                width: frame.size.width,
                height: frame.size.height
              ) else {
            return
        }

        windowFrameRepository.save(windowFrame)
    }

    @objc func showSettingsWindow(_ sender: Any?) {
        guard let mainWindow = windowController?.window else {
            return
        }

        let commandID = (sender as? Notification)?.userInfo?["commandID"] as? CommandID
        settingsWindowController.presentAsSheet(for: mainWindow, focusedCommandID: commandID)
    }

    @objc func showCommandPalette(_ sender: Any?) {
        (windowController?.window?.contentViewController as? DualPaneViewController)?.showCommandPaletteAction(sender)
    }

    @objc func showAboutPanel(_ sender: Any?) {
        let versionInfo = AppVersionInfo.current()
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: versionInfo.aboutPanelVersion
        ])
    }

    @objc func quitApplication(_ sender: Any?) {
        NSApp.terminate(sender)
    }

    @objc private func settingsDidChange(_ notification: Notification) {
        if let showsPreviewPane = notification.userInfo?[SettingsNotificationKey.showsPreviewPane] as? Bool {
            appSettings.showsPreviewPane = showsPreviewPane
        }

        if let previewPanePosition = notification.userInfo?[SettingsNotificationKey.previewPanePosition] as? PreviewPanePosition {
            appSettings.previewPanePosition = previewPanePosition
        }

        if let previewPaneWidthRatio = notification.userInfo?[SettingsNotificationKey.previewPaneWidthRatio] as? Double {
            appSettings.previewPaneWidthRatio = AppSettings.normalizedPreviewPaneWidthRatio(previewPaneWidthRatio)
        }

        if let showsHiddenFiles = notification.userInfo?[SettingsNotificationKey.showsHiddenFiles] as? Bool {
            appSettings.showsHiddenFiles = showsHiddenFiles
        }

        if let incrementalSearchPriority = notification.userInfo?[SettingsNotificationKey.incrementalSearchPriority] as? Bool {
            appSettings.incrementalSearchPriority = incrementalSearchPriority
        }
        if let showsButton = notification.userInfo?[SettingsNotificationKey.showsCommandPaletteButton] as? Bool {
            appSettings.showsCommandPaletteButton = showsButton
            windowController?.setCommandPaletteButtonVisible(showsButton)
        }

        if let usesAlternatingRowBackgrounds = notification.userInfo?[SettingsNotificationKey.usesAlternatingRowBackgrounds] as? Bool {
            appSettings.usesAlternatingRowBackgrounds = usesAlternatingRowBackgrounds
        }

        if let showsFileIcons = notification.userInfo?[SettingsNotificationKey.showsFileIcons] as? Bool {
            appSettings.showsFileIcons = showsFileIcons
        }

        if let showsFileTagColors = notification.userInfo?[SettingsNotificationKey.showsFileTagColors] as? Bool {
            appSettings.showsFileTagColors = showsFileTagColors
        }

        if let showsFileExtensionsSeparately = notification.userInfo?[SettingsNotificationKey.showsFileExtensionsSeparately] as? Bool {
            appSettings.showsFileExtensionsSeparately = showsFileExtensionsSeparately
        }
        if let showsMultiStrokeKeyCandidates = notification.userInfo?[SettingsNotificationKey.showsMultiStrokeKeyCandidates] as? Bool {
            appSettings.showsMultiStrokeKeyCandidates = showsMultiStrokeKeyCandidates
        }

        if let movesCursorAfterMarking = notification.userInfo?[SettingsNotificationKey.movesCursorAfterMarking] as? Bool {
            appSettings.movesCursorAfterMarking = movesCursorAfterMarking
        }

        if let movesToCreatedFolder = notification.userInfo?[SettingsNotificationKey.movesToCreatedFolder] as? Bool {
            appSettings.movesToCreatedFolder = movesToCreatedFolder
        }

        if let selectsPreviousDirectoryAfterMovingToParent = notification.userInfo?[SettingsNotificationKey.selectsPreviousDirectoryAfterMovingToParent] as? Bool {
            appSettings.selectsPreviousDirectoryAfterMovingToParent = selectsPreviousDirectoryAfterMovingToParent
        }

        if let confirmsBeforeCopy = notification.userInfo?[SettingsNotificationKey.confirmsBeforeCopy] as? Bool {
            appSettings.confirmsBeforeCopy = confirmsBeforeCopy
        }

        if let confirmsBeforeMove = notification.userInfo?[SettingsNotificationKey.confirmsBeforeMove] as? Bool {
            appSettings.confirmsBeforeMove = confirmsBeforeMove
        }

        if let confirmsBeforeTrash = notification.userInfo?[SettingsNotificationKey.confirmsBeforeTrash] as? Bool {
            appSettings.confirmsBeforeTrash = confirmsBeforeTrash
        }

        if let confirmsBeforeQuit = notification.userInfo?[SettingsNotificationKey.confirmsBeforeQuit] as? Bool {
            appSettings.confirmsBeforeQuit = confirmsBeforeQuit
        }

        if let allowsExternalFileDrag = notification.userInfo?[SettingsNotificationKey.allowsExternalFileDrag] as? Bool {
            appSettings.allowsExternalFileDrag = allowsExternalFileDrag
        }

        if let treatZipAsDirectory = notification.userInfo?[SettingsNotificationKey.treatZipAsDirectory] as? Bool {
            appSettings.treatZipAsDirectory = treatZipAsDirectory
        }

        if let fileOperationDetailLogLimit = notification.userInfo?[SettingsNotificationKey.fileOperationDetailLogLimit] as? Int {
            appSettings.fileOperationDetailLogLimit = fileOperationDetailLogLimit
        }

        if let fileListFontSize = notification.userInfo?[SettingsNotificationKey.fileListFontSize] as? Int {
            appSettings.fileListFontSize = FileListFontSize.normalized(fileListFontSize)
        }

        if let appLanguage = notification.userInfo?[SettingsNotificationKey.appLanguage] as? AppLanguage {
            appSettings.appLanguage = appLanguage
            L10n.setAppLanguage(appLanguage)
            configureMainMenu()
        }

        if let returnKeyBehavior = notification.userInfo?[SettingsNotificationKey.returnKeyBehavior] as? ReturnKeyBehavior {
            appSettings.returnKeyBehavior = returnKeyBehavior
        }

        if let incrementalSearchMatchMode = notification.userInfo?[SettingsNotificationKey.incrementalSearchMatchMode] as? IncrementalSearchMatchMode {
            appSettings.incrementalSearchMatchMode = incrementalSearchMatchMode
        }

        if let leftStartupPathMode = notification.userInfo?[SettingsNotificationKey.leftStartupPathMode] as? StartupPathMode {
            appSettings.leftStartupPathMode = leftStartupPathMode
        }

        if let rightStartupPathMode = notification.userInfo?[SettingsNotificationKey.rightStartupPathMode] as? StartupPathMode {
            appSettings.rightStartupPathMode = rightStartupPathMode
        }

        if let leftStartupPath = notification.userInfo?[SettingsNotificationKey.leftStartupPath] as? String {
            appSettings.leftStartupPath = leftStartupPath
        }

        if let rightStartupPath = notification.userInfo?[SettingsNotificationKey.rightStartupPath] as? String {
            appSettings.rightStartupPath = rightStartupPath
        }

        if let keyBindingSet = notification.userInfo?[SettingsNotificationKey.keyBindingSet] as? KeyBindingSet {
            appSettings.keyBindingSet = keyBindingSet
        }

        if let displayThemeSet = notification.userInfo?[SettingsNotificationKey.displayThemeSet] as? DisplayThemeSet {
            appSettings.displayThemeSet = displayThemeSet
        }

        if let associations = notification.userInfo?[SettingsNotificationKey.fileTypeAssociations] as? [FileTypeAssociation] {
            appSettings.fileTypeAssociations = associations
        }

        if let scope = notification.userInfo?[SettingsNotificationKey.fileTypeColorScope] as? FileTypeColorScope {
            appSettings.fileTypeColorScope = scope
        }

        settingsRepository.save(settingsForPersistence())
    }

    @objc private func jumpPathEntriesDidChange(_ notification: Notification) {
        guard let entries = notification.userInfo?[SettingsNotificationKey.jumpPathEntries] as? [JumpPathEntry] else {
            return
        }

        appSettings.jumpPathEntries = entries
        settingsRepository.save(settingsForPersistence())
    }

    @objc private func paneDirectoriesDidChange(_ notification: Notification) {
        guard let leftPath = notification.userInfo?[SettingsNotificationKey.leftPanePath] as? String,
              let rightPath = notification.userInfo?[SettingsNotificationKey.rightPanePath] as? String else {
            return
        }

        appSettings.setPanePaths(left: leftPath, right: rightPath)
        if let leftHistory = notification.userInfo?[SettingsNotificationKey.leftPaneNavigationHistory] as? NavigationHistory,
           let rightHistory = notification.userInfo?[SettingsNotificationKey.rightPaneNavigationHistory] as? NavigationHistory {
            appSettings.setPaneNavigationHistories(left: leftHistory, right: rightHistory)
        }
        if let leftSortDescriptor = notification.userInfo?[SettingsNotificationKey.leftPaneSortDescriptor] as? FileSortDescriptor,
           let rightSortDescriptor = notification.userInfo?[SettingsNotificationKey.rightPaneSortDescriptor] as? FileSortDescriptor {
            appSettings.setPaneSortDescriptors(left: leftSortDescriptor, right: rightSortDescriptor)
        }
        settingsRepository.save(settingsForPersistence())
    }

    @objc private func filePatternHistoryDidChange(_ notification: Notification) {
        guard let history = notification.userInfo?[SettingsNotificationKey.filePatternHistory] as? FilePatternHistory else {
            return
        }

        appSettings.filePatternHistory = history
        settingsRepository.save(settingsForPersistence())
    }

    private func settingsForPersistence() -> AppSettings {
        var settings = appSettings
        if launchOptions.appLanguage != nil {
            settings.appLanguage = storedAppSettings.appLanguage
        }
        if launchOptions.themeID != nil {
            settings.displayThemeSet = storedAppSettings.displayThemeSet
        }
        return settings
    }

    private func configureMainMenu() {
        NSApp.mainMenu = makeMainMenu()
    }

    func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName

        appMenu.addItem(
            withTitle: L10n.format("app.menu.about", appName),
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        ).target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: L10n.string("app.menu.settings"),
            action: #selector(showSettingsWindow(_:)),
            keyEquivalent: ","
        ).target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: L10n.format("app.menu.quit", appName),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n.string("app.menu.edit"))
        editMenu.addItem(
            withTitle: L10n.string("app.menu.cut"),
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        editMenu.addItem(
            withTitle: L10n.string("app.menu.copy"),
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(
            withTitle: L10n.string("app.menu.paste"),
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        editMenu.addItem(.separator())
        editMenu.addItem(
            withTitle: L10n.string("app.menu.selectAll"),
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: L10n.string("app.menu.help"))
        helpMenu.addItem(withTitle: L10n.string("commandPalette.title"),
                         action: #selector(showCommandPalette(_:)), keyEquivalent: "").target = self
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        return mainMenu
    }

    private func promptForQuitConfirmation() -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.quit.title")
        alert.informativeText = L10n.string("alert.quit.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("alert.quit.quit"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        return alert.runModal() == .alertFirstButtonReturn
    }
}

extension Notification.Name {
    static let settingsWindowRequested = Notification.Name("MafxSettingsWindowRequested")
    static let settingsDidChange = Notification.Name("MafxSettingsDidChange")
    static let jumpPathEntriesDidChange = Notification.Name("MafxJumpPathEntriesDidChange")
    static let paneDirectoriesDidChange = Notification.Name("MafxPaneDirectoriesDidChange")
    static let filePatternHistoryDidChange = Notification.Name("MafxFilePatternHistoryDidChange")
    static let applicationQuitRequested = Notification.Name("MafxApplicationQuitRequested")
}

enum SettingsNotificationKey {
    static let filePatternHistory = "filePatternHistory"
    static let showsHiddenFiles = "showsHiddenFiles"
    static let incrementalSearchPriority = "incrementalSearchPriority"
    static let showsCommandPaletteButton = "showsCommandPaletteButton"
    static let showsPreviewPane = "showsPreviewPane"
    static let previewPanePosition = "previewPanePosition"
    static let previewPaneWidthRatio = "previewPaneWidthRatio"
    static let usesAlternatingRowBackgrounds = "usesAlternatingRowBackgrounds"
    static let showsFileIcons = "showsFileIcons"
    static let showsFileTagColors = "showsFileTagColors"
    static let showsFileExtensionsSeparately = "showsFileExtensionsSeparately"
    static let showsMultiStrokeKeyCandidates = "showsMultiStrokeKeyCandidates"
    static let movesCursorAfterMarking = "movesCursorAfterMarking"
    static let movesToCreatedFolder = "movesToCreatedFolder"
    static let selectsPreviousDirectoryAfterMovingToParent = "selectsPreviousDirectoryAfterMovingToParent"
    static let confirmsBeforeCopy = "confirmsBeforeCopy"
    static let confirmsBeforeMove = "confirmsBeforeMove"
    static let confirmsBeforeTrash = "confirmsBeforeTrash"
    static let confirmsBeforeQuit = "confirmsBeforeQuit"
    static let allowsExternalFileDrag = "allowsExternalFileDrag"
    static let treatZipAsDirectory = "treatZipAsDirectory"
    static let fileOperationDetailLogLimit = "fileOperationDetailLogLimit"
    static let fileListFontSize = "fileListFontSize"
    static let appLanguage = "appLanguage"
    static let returnKeyBehavior = "returnKeyBehavior"
    static let incrementalSearchMatchMode = "incrementalSearchMatchMode"
    static let leftStartupPathMode = "leftStartupPathMode"
    static let rightStartupPathMode = "rightStartupPathMode"
    static let leftStartupPath = "leftStartupPath"
    static let rightStartupPath = "rightStartupPath"
    static let jumpPathEntries = "jumpPathEntries"
    static let leftPanePath = "leftPanePath"
    static let rightPanePath = "rightPanePath"
    static let leftPaneNavigationHistory = "leftPaneNavigationHistory"
    static let rightPaneNavigationHistory = "rightPaneNavigationHistory"
    static let leftPaneSortDescriptor = "leftPaneSortDescriptor"
    static let rightPaneSortDescriptor = "rightPaneSortDescriptor"
    static let keyBindingSet = "keyBindingSet"
    static let displayThemeSet = "displayThemeSet"
    static let fileTypeAssociations = "fileTypeAssociations"
    static let fileTypeColorScope = "fileTypeColorScope"
}
