import XCTest
@testable import MafxCore

final class SettingsRepositoryTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "MafxCoreTests.SettingsRepository.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testCommandPaletteButtonVisibilityRoundTrips() {
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        var settings = AppSettings()
        XCTAssertTrue(settings.showsCommandPaletteButton)
        settings.showsCommandPaletteButton = false
        repository.save(settings)
        XCTAssertFalse(repository.load().showsCommandPaletteButton)
    }

    func testLoadReturnsDefaultSettingsWhenUserDefaultsIsEmpty() {
        let defaultSettings = AppSettings(
            showsHiddenFiles: true,
            showsPreviewPane: true,
            usesAlternatingRowBackgrounds: true,
            showsFileIcons: false,
            showsFileTagColors: false,
            showsFileExtensionsSeparately: false,
            showsMultiStrokeKeyCandidates: false,
            movesCursorAfterMarking: false,
            movesToCreatedFolder: false,
            selectsPreviousDirectoryAfterMovingToParent: false,
            confirmsBeforeCopy: false,
            confirmsBeforeMove: false,
            confirmsBeforeTrash: false,
            confirmsBeforeQuit: false,
            fileOperationDetailLogLimit: 0,
            fileListFontSize: 18,
            appLanguage: .japanese,
            returnKeyBehavior: .previewFileOrOpenDirectory,
            incrementalSearchMatchMode: .exact,
            previewPanePosition: .left,
            previewPaneWidthRatio: 0.44,
            leftStartupPathMode: .specified,
            rightStartupPathMode: .previous,
            leftStartupPath: "/tmp/start-left",
            jumpPathEntries: [
                JumpPathEntry(displayName: "Work", path: "/tmp/work")
            ],
            leftPanePath: "/tmp/left",
            rightPanePath: "/tmp/right",
            leftPaneNavigationHistory: NavigationHistory(paths: ["/tmp/left"], currentIndex: 0),
            rightPaneNavigationHistory: NavigationHistory(paths: ["/tmp/right"], currentIndex: 0),
            filePatternHistory: FilePatternHistory(entries: ["*.swift", "*.md"]),
            leftPaneSortDescriptor: FileSortDescriptor(criterion: .byteSize, direction: .descending),
            rightPaneSortDescriptor: FileSortDescriptor(criterion: .modificationDate, direction: .ascending),
            displayThemeSet: DisplayThemeSet(selectedThemeID: DisplayTheme.dark.id)
        )
        let repository = UserDefaultsSettingsRepository(
            userDefaults: userDefaults,
            defaultSettings: defaultSettings
        )

        XCTAssertEqual(repository.load(), defaultSettings)
    }

    func testSaveAndLoadRoundTripsSettings() {
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        var keyBindingSet = KeyBindingSet.default
        keyBindingSet.addSequence(KeyBindingSequence(KeyStroke(key: "X")), to: .copyMarkedItems)
        let settings = AppSettings(
            showsHiddenFiles: true,
            incrementalSearchPriority: true,
            showsPreviewPane: true,
            usesAlternatingRowBackgrounds: true,
            showsFileIcons: false,
            showsFileTagColors: false,
            showsFileExtensionsSeparately: false,
            showsMultiStrokeKeyCandidates: false,
            movesCursorAfterMarking: false,
            movesToCreatedFolder: false,
            selectsPreviousDirectoryAfterMovingToParent: false,
            confirmsBeforeCopy: false,
            confirmsBeforeMove: false,
            confirmsBeforeTrash: false,
            confirmsBeforeQuit: false,
            treatZipAsDirectory: true,
            fileOperationDetailLogLimit: 12,
            fileListFontSize: 18,
            appLanguage: .english,
            returnKeyBehavior: .disabled,
            incrementalSearchMatchMode: .contains,
            previewPanePosition: .left,
            previewPaneWidthRatio: 0.44,
            leftStartupPathMode: .specified,
            rightStartupPathMode: .specified,
            leftStartupPath: "/tmp/./start-left",
            rightStartupPath: "/tmp/./start-right",
            jumpPathEntries: [
                JumpPathEntry(displayName: "One", path: "/tmp/one"),
                JumpPathEntry(displayName: "", path: "/tmp/two")
            ],
            leftPanePath: "/tmp/left",
            rightPanePath: "/tmp/right",
            leftPaneNavigationHistory: NavigationHistory(paths: ["/tmp", "/tmp/left"], currentIndex: 1),
            rightPaneNavigationHistory: NavigationHistory(paths: ["/tmp", "/tmp/right"], currentIndex: 1),
            filePatternHistory: FilePatternHistory(entries: ["*.swift", "*.md"]),
            leftPaneSortDescriptor: FileSortDescriptor(criterion: .fileExtension, direction: .ascending),
            rightPaneSortDescriptor: FileSortDescriptor(criterion: .byteSize, direction: .descending),
            keyBindingSet: keyBindingSet,
            displayThemeSet: DisplayThemeSet(
                selectedThemeID: DisplayTheme.dark.id,
                themes: DisplayTheme.defaultThemes + [
                    DisplayTheme(
                        id: "custom",
                        name: "Custom",
                        base: DisplayColorPair(
                            background: DisplayColor(hex: "#101010"),
                            foreground: DisplayColor(hex: "#F0F0F0")
                        )
                    )
                ]
            ),
            fileTypeAssociations: [
                FileTypeAssociation(
                    extensions: ["txt", "md"],
                    applicationPath: "/tmp/example.app",
                    color: DisplayColor(hex: "#FF0000")
                )
            ],
            fileTypeColorScope: .fileExtension
        )

        repository.save(settings)

        XCTAssertEqual(repository.load(), settings)
    }

    func testLoadFillsMissingDefaultKeyBindingEntries() {
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let keyBindingSet = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init(.init(key: "X"))])
        ])
        let settings = AppSettings(
            leftPanePath: "/tmp/left",
            rightPanePath: "/tmp/right",
            keyBindingSet: keyBindingSet
        )

        repository.save(settings)
        let loadedSettings = repository.load()

        XCTAssertEqual(loadedSettings.keyBindingSet.sequences(for: .copyMarkedItems), [.init(.init(key: "X"))])
        XCTAssertEqual(loadedSettings.keyBindingSet.sequences(for: .showTagFilterList), [.init(.init(key: "T"))])
        XCTAssertEqual(
            loadedSettings.keyBindingSet.sequences(for: .showTagEditList),
            [.init(.init(key: "T", modifiers: .shift))]
        )
    }

    func testLoadReservesUnmodifiedReturnForReturnKeyBehavior() {
        let repository = UserDefaultsSettingsRepository(userDefaults: userDefaults)
        let settings = AppSettings(
            returnKeyBehavior: .previewFileOrOpenDirectory,
            leftPanePath: "/tmp/left",
            rightPanePath: "/tmp/right",
            keyBindingSet: KeyBindingSet(entries: [
                KeyBindingEntry(commandID: .openSelectedDirectory, sequences: [.init(.init(key: "Return"))]),
                KeyBindingEntry(commandID: .previewSelectedFile, sequences: [.init(.init(key: "P"))])
            ])
        )

        repository.save(settings)
        let loaded = repository.load()

        XCTAssertEqual(loaded.returnKeyBehavior, .previewFileOrOpenDirectory)
        XCTAssertEqual(loaded.keyBindingSet.sequences(for: .openSelectedDirectory), [])
        XCTAssertEqual(loaded.keyBindingSet.sequences(for: .previewSelectedFile), [.init(.init(key: "P"))])
    }

    func testLoadAddsBuiltInThemesToExistingSavedThemeSet() throws {
        let legacyThemes = DisplayThemeSet(
            selectedThemeID: "dark",
            themes: [
                DisplayTheme(
                    id: "light",
                    name: "ライト",
                    base: DisplayColorPair(
                        background: DisplayColor(hex: "#FFFFFF"),
                        foreground: DisplayColor(hex: "#1F2328")
                    )
                ),
                DisplayTheme(
                    id: "dark",
                    name: "ダーク",
                    base: DisplayColorPair(
                        background: DisplayColor(hex: "#111111"),
                        foreground: DisplayColor(hex: "#E6E6E6")
                    )
                )
            ]
        )
        let data = try JSONEncoder().encode(legacyThemes)
        userDefaults.set(data, forKey: "settings.displayThemeSet")

        let loaded = UserDefaultsSettingsRepository(userDefaults: userDefaults).load().displayThemeSet

        XCTAssertEqual(loaded.selectedThemeID, "dark")
        XCTAssertEqual(loaded.themes, DisplayTheme.defaultThemes)
    }

    func testAppSettingsAppliesSettingsStateAndNormalizesPanePaths() {
        var settings = AppSettings(leftPanePath: "/tmp/./left", rightPanePath: "/tmp/./right")
        var state = SettingsState()
        state.setToggle(.useAlternatingRowBackgrounds, isOn: true)
        state.focusItem(at: 3)
        _ = state.toggleFocusedItem()
        state.addJumpPath(displayName: "Work", path: "/tmp/work")
        state.setChoice(.leftStartupPathMode, to: .startupPathMode(.specified))
        state.setStartupPath("/tmp/./start-left", for: .leftStartupPathMode)
        state.setChoice(.rightStartupPathMode, to: .startupPathMode(.specified))
        state.setStartupPath(" ", for: .rightStartupPathMode)
        state.addKeyBindingSequence(KeyBindingSequence(KeyStroke(key: "X")), to: .copyMarkedItems)
        state.selectDisplayTheme(id: DisplayTheme.dark.id)

        settings.applySettingsState(state)
        settings.setPanePaths(left: "/tmp/left/..", right: "/tmp/right/.")
        settings.setPaneSortDescriptors(
            left: FileSortDescriptor(criterion: .modificationDate, direction: .descending),
            right: FileSortDescriptor(criterion: .fileExtension, direction: .ascending)
        )

        XCTAssertEqual(settings.showsHiddenFiles, state.showsHiddenFiles)
        XCTAssertEqual(settings.usesAlternatingRowBackgrounds, state.usesAlternatingRowBackgrounds)
        XCTAssertEqual(settings.showsFileIcons, state.showsFileIcons)
        XCTAssertEqual(settings.showsFileTagColors, state.showsFileTagColors)
        XCTAssertEqual(settings.showsFileExtensionsSeparately, state.showsFileExtensionsSeparately)
        XCTAssertEqual(settings.showsMultiStrokeKeyCandidates, state.showsMultiStrokeKeyCandidates)
        XCTAssertEqual(settings.movesCursorAfterMarking, state.movesCursorAfterMarking)
        XCTAssertEqual(settings.movesToCreatedFolder, state.movesToCreatedFolder)
        XCTAssertEqual(
            settings.selectsPreviousDirectoryAfterMovingToParent,
            state.selectsPreviousDirectoryAfterMovingToParent
        )
        XCTAssertEqual(settings.confirmsBeforeCopy, state.confirmsBeforeCopy)
        XCTAssertEqual(settings.confirmsBeforeMove, state.confirmsBeforeMove)
        XCTAssertEqual(settings.confirmsBeforeTrash, state.confirmsBeforeTrash)
        XCTAssertEqual(settings.confirmsBeforeQuit, state.confirmsBeforeQuit)
        XCTAssertEqual(settings.appLanguage, state.appLanguage)
        XCTAssertEqual(settings.leftStartupPathMode, .specified)
        XCTAssertEqual(settings.rightStartupPathMode, .specified)
        XCTAssertEqual(settings.leftStartupPath, "/tmp/start-left")
        XCTAssertEqual(settings.rightStartupPath, "")
        XCTAssertEqual(settings.jumpPathEntries, state.jumpPathEntries)
        XCTAssertEqual(settings.keyBindingSet, state.keyBindingSet)
        XCTAssertEqual(settings.displayThemeSet, state.displayThemeSet)
        XCTAssertEqual(settings.leftPanePath, JumpPathEntry.normalizedPath("/tmp/left/.."))
        XCTAssertEqual(settings.rightPanePath, JumpPathEntry.normalizedPath("/tmp/right/."))
        XCTAssertEqual(
            settings.leftPaneSortDescriptor,
            FileSortDescriptor(criterion: .modificationDate, direction: .descending)
        )
        XCTAssertEqual(
            settings.rightPaneSortDescriptor,
            FileSortDescriptor(criterion: .fileExtension, direction: .ascending)
        )
    }

    func testAppSettingsResolvesStartupPaths() {
        let previousSettings = AppSettings(leftPanePath: "/tmp/left", rightPanePath: "/tmp/right")

        XCTAssertEqual(previousSettings.effectiveLeftPanePath, "/tmp/left")
        XCTAssertEqual(previousSettings.effectiveRightPanePath, "/tmp/right")

        let specifiedSettings = AppSettings(
            leftStartupPathMode: .specified,
            rightStartupPathMode: .specified,
            leftStartupPath: "/tmp/./start-left",
            rightStartupPath: "",
            leftPanePath: "/tmp/left",
            rightPanePath: "/tmp/right"
        )

        XCTAssertEqual(specifiedSettings.effectiveLeftPanePath, "/tmp/start-left")
        XCTAssertEqual(specifiedSettings.effectiveRightPanePath, "/tmp/right")
    }
}
