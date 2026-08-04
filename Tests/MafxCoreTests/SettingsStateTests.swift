import XCTest
@testable import MafxCore

final class SettingsStateTests: XCTestCase {
    func testFileListFontSizeDefaultsToStandardAndNormalizesRange() {
        var state = SettingsState(fileListFontSize: 1)

        XCTAssertEqual(state.fileListFontSize, FileListFontSize.minimum)

        state.setNumericValue(100, for: .fileListFontSize)

        XCTAssertEqual(state.fileListFontSize, FileListFontSize.maximum)
    }

    func testFileOperationDetailLogLimitDefaultsToTenAndAllowsZero() {
        var state = SettingsState()

        XCTAssertEqual(state.fileOperationDetailLogLimit, 10)

        state.setNumericValue(0, for: .fileOperationDetailLogLimit)

        XCTAssertEqual(state.fileOperationDetailLogLimit, 0)
    }

    func testFileOperationDetailLogLimitNormalizesNegativeValuesToZero() {
        var state = SettingsState(fileOperationDetailLogLimit: -1)

        XCTAssertEqual(state.fileOperationDetailLogLimit, 0)

        state.setNumericValue(-10, for: .fileOperationDetailLogLimit)

        XCTAssertEqual(state.fileOperationDetailLogLimit, 0)
    }

    func testFileTypeAssociationNormalizesExtensionsAndMatchesCaseInsensitively() {
        let association = FileTypeAssociation(extensions: [".TXT, md", "txt"])

        XCTAssertEqual(association.extensions, ["txt", "md"])
        XCTAssertTrue(association.matches(fileExtension: "TXT"))
        XCTAssertTrue(association.matches(fileExtension: ".md"))
        XCTAssertFalse(association.matches(fileExtension: "pdf"))
    }

    func testFileTypeAssociationFindsDuplicatesAcrossAssociationsAfterNormalization() {
        let duplicates = FileTypeAssociation.duplicateExtensions(in: [
            FileTypeAssociation(extensions: ["txt", "md"]),
            FileTypeAssociation(extensions: [".TXT", "pdf"]),
            FileTypeAssociation(extensions: ["MD"])
        ])

        XCTAssertEqual(duplicates, ["txt", "md"])
    }

    func testFileTypeAssociationResolverPrefersRegisteredExtensionOverOther() {
        let other = FileTypeAssociation.other(applicationPath: "/tmp/other.app")
        let text = FileTypeAssociation(extensions: ["txt"], applicationPath: "/tmp/text.app")
        let resolver = FileTypeAssociationResolver(associations: [other, text])

        XCTAssertEqual(resolver.association(forFileExtension: "txt")?.applicationPath, "/tmp/text.app")
        XCTAssertEqual(resolver.association(forFileExtension: "PDF")?.applicationPath, "/tmp/other.app")
        XCTAssertEqual(resolver.association(forFileExtension: "")?.applicationPath, "/tmp/other.app")
    }

    func testFileTypeAssociationAllowsOnlyOneOtherAssociation() {
        XCTAssertTrue(FileTypeAssociation.hasDuplicateOtherExtensionsAssociation(in: [
            .other(),
            FileTypeAssociation(extensions: ["txt"]),
            .other()
        ]))
    }

    func testFileTypeAssociationDecodesLegacySettingsAsExtensionAssociation() throws {
        let data = Data("""
        {"id":"00000000-0000-0000-0000-000000000001","extensions":["txt"],"applicationPath":"","color":null}
        """.utf8)

        let association = try JSONDecoder().decode(FileTypeAssociation.self, from: data)

        XCTAssertFalse(association.matchesOtherExtensions)
        XCTAssertEqual(association.extensions, ["txt"])
    }

    func testFileTypeAssociationsCanBeAddedUpdatedAndRemoved() {
        var state = SettingsState()
        state.addFileTypeAssociation(FileTypeAssociation(extensions: ["txt"]))
        state.setFileTypeColorScope(.fileExtension)
        state.updateFileTypeAssociation(at: 0, with: FileTypeAssociation(extensions: ["md"]))

        XCTAssertEqual(state.fileTypeAssociations.map(\.extensionsText), ["md"])
        XCTAssertEqual(state.fileTypeColorScope, .fileExtension)

        state.removeFileTypeAssociation(at: 0)
        XCTAssertTrue(state.fileTypeAssociations.isEmpty)
    }
    func testMoveTabSelectionClampsToBoundsAndResetsFocusedItem() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "A", items: [SettingsItem(title: "A1")]),
                SettingsTab(title: "B", items: [SettingsItem(title: "B1"), SettingsItem(title: "B2")])
            ],
            selectedTabIndex: 0,
            focusedItemIndex: 0
        )

        state.moveItemFocus(by: 10)
        state.moveTabSelection(by: 1)

        XCTAssertEqual(state.selectedTabIndex, 1)
        XCTAssertEqual(state.focusedItemIndex, 0)

        state.moveTabSelection(by: 10)

        XCTAssertEqual(state.selectedTabIndex, 1)

        state.moveTabSelection(by: -10)

        XCTAssertEqual(state.selectedTabIndex, 0)
    }

    func testMoveItemFocusClampsWithinSelectedTabItems() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [SettingsItem(title: "One"), SettingsItem(title: "Two")])
            ]
        )

        state.moveItemFocus(by: 10)
        XCTAssertEqual(state.focusedItemIndex, 1)

        state.moveItemFocus(by: -10)
        XCTAssertEqual(state.focusedItemIndex, 0)

        state.moveItemFocus(by: -1)
        XCTAssertEqual(state.focusArea, .tabs)
    }

    func testFocusItemUpdatesFocusWhenIndexExists() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [SettingsItem(title: "One"), SettingsItem(title: "Two")])
            ]
        )

        state.focusItem(at: 1)

        XCTAssertEqual(state.focusedItemIndex, 1)
        XCTAssertEqual(state.focusArea, .items)

        state.focusItem(at: 10)

        XCTAssertEqual(state.focusedItemIndex, 1)
    }

    func testFocusAreaCanMoveBetweenTabsAndItems() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [SettingsItem(title: "One"), SettingsItem(title: "Two")])
            ]
        )

        state.focusTabs()

        XCTAssertEqual(state.focusArea, .tabs)

        state.focusItems()

        XCTAssertEqual(state.focusArea, .items)
    }

    func testEmptyTabsKeepSelectionAndFocusAtZero() {
        var state = SettingsState(tabs: [])

        state.moveTabSelection(by: 1)
        state.moveItemFocus(by: 1)

        XCTAssertEqual(state.selectedTabIndex, 0)
        XCTAssertEqual(state.focusedItemIndex, 0)
        XCTAssertNil(state.selectedTab)
    }

    func testToggleFocusedItemUpdatesShowHiddenFilesSetting() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "隠しファイルを表示する", toggleID: .showHiddenFiles)
                ])
            ]
        )

        let toggledID = state.toggleFocusedItem()

        XCTAssertEqual(toggledID, .showHiddenFiles)
        XCTAssertTrue(state.showsHiddenFiles)
        XCTAssertTrue(state.isToggleOn(.showHiddenFiles))
    }

    func testMoveCursorAfterMarkingDefaultsToOn() {
        let state = SettingsState()

        XCTAssertTrue(state.movesCursorAfterMarking)
        XCTAssertTrue(state.isToggleOn(.moveCursorAfterMarking))
    }

    func testAllowExternalFileDragDefaultsToOffAndCanBeToggled() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "Allow external file drag", toggleID: .allowExternalFileDrag)
                ])
            ]
        )

        XCTAssertFalse(state.allowsExternalFileDrag)
        XCTAssertFalse(state.isToggleOn(.allowExternalFileDrag))

        XCTAssertEqual(state.toggleFocusedItem(), .allowExternalFileDrag)
        XCTAssertTrue(state.allowsExternalFileDrag)
    }

    func testSelectPreviousDirectoryAfterMovingToParentDefaultsToOnAndCanBeToggled() {
        var state = SettingsState()

        XCTAssertTrue(state.selectsPreviousDirectoryAfterMovingToParent)
        XCTAssertTrue(state.isToggleOn(.selectPreviousDirectoryAfterMovingToParent))

        state.setToggle(.selectPreviousDirectoryAfterMovingToParent, isOn: false)

        XCTAssertFalse(state.selectsPreviousDirectoryAfterMovingToParent)
        XCTAssertFalse(state.isToggleOn(.selectPreviousDirectoryAfterMovingToParent))
    }

    func testShowFileIconsDefaultsToOnAndCanBeToggled() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "ファイルアイコンを表示する", toggleID: .showFileIcons)
                ])
            ]
        )

        XCTAssertTrue(state.showsFileIcons)
        XCTAssertTrue(state.isToggleOn(.showFileIcons))

        XCTAssertEqual(state.toggleFocusedItem(), .showFileIcons)
        XCTAssertFalse(state.showsFileIcons)
    }

    func testAlternatingRowBackgroundsDefaultsToOffAndCanBeToggled() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "背景色を交互に切り替える", toggleID: .useAlternatingRowBackgrounds)
                ])
            ]
        )

        XCTAssertFalse(state.usesAlternatingRowBackgrounds)
        XCTAssertFalse(state.isToggleOn(.useAlternatingRowBackgrounds))

        XCTAssertEqual(state.toggleFocusedItem(), .useAlternatingRowBackgrounds)
        XCTAssertTrue(state.usesAlternatingRowBackgrounds)
    }

    func testShowFileTagColorsDefaultsToOnAndCanBeToggled() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "色タグを表示する", toggleID: .showFileTagColors)
                ])
            ]
        )

        XCTAssertTrue(state.showsFileTagColors)
        XCTAssertTrue(state.isToggleOn(.showFileTagColors))

        XCTAssertEqual(state.toggleFocusedItem(), .showFileTagColors)
        XCTAssertFalse(state.showsFileTagColors)
    }

    func testShowFileExtensionsSeparatelyDefaultsToOnAndCanBeToggled() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "拡張子を分けて表示する", toggleID: .showFileExtensionsSeparately)
                ])
            ]
        )

        XCTAssertTrue(state.showsFileExtensionsSeparately)
        XCTAssertTrue(state.isToggleOn(.showFileExtensionsSeparately))

        XCTAssertEqual(state.toggleFocusedItem(), .showFileExtensionsSeparately)
        XCTAssertFalse(state.showsFileExtensionsSeparately)
    }

    func testShowMultiStrokeKeyCandidatesDefaultsToOnAndCanBeToggled() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "複数ストロークキー候補を表示する", toggleID: .showMultiStrokeKeyCandidates)
                ])
            ]
        )

        XCTAssertTrue(state.showsMultiStrokeKeyCandidates)
        XCTAssertTrue(state.isToggleOn(.showMultiStrokeKeyCandidates))

        XCTAssertEqual(state.toggleFocusedItem(), .showMultiStrokeKeyCandidates)
        XCTAssertFalse(state.showsMultiStrokeKeyCandidates)
    }

    func testMoveToCreatedFolderDefaultsToOn() {
        let state = SettingsState()

        XCTAssertTrue(state.movesToCreatedFolder)
        XCTAssertTrue(state.isToggleOn(.moveToCreatedFolder))
    }

    func testConfirmBeforeTrashDefaultsToOn() {
        let state = SettingsState()

        XCTAssertTrue(state.confirmsBeforeTrash)
        XCTAssertTrue(state.isToggleOn(.confirmBeforeTrash))
    }

    func testConfirmBeforeCopyMoveAndQuitDefaultToOn() {
        let state = SettingsState()

        XCTAssertTrue(state.confirmsBeforeCopy)
        XCTAssertTrue(state.isToggleOn(.confirmBeforeCopy))
        XCTAssertTrue(state.confirmsBeforeMove)
        XCTAssertTrue(state.isToggleOn(.confirmBeforeMove))
        XCTAssertTrue(state.confirmsBeforeQuit)
        XCTAssertTrue(state.isToggleOn(.confirmBeforeQuit))
    }

    func testDefaultTabsPlaceConfirmationItemsInGeneral() {
        let state = SettingsState()

        XCTAssertEqual(state.tabs.map(\.title), ["General", "Keybindings", "Theme", "Bookmarks", "File Types"])

        let generalToggleIDs = state.tabs[0].items.compactMap(\.toggleID)
        XCTAssertTrue(generalToggleIDs.contains(.confirmBeforeCopy))
        XCTAssertTrue(generalToggleIDs.contains(.confirmBeforeMove))
        XCTAssertTrue(generalToggleIDs.contains(.confirmBeforeTrash))
        XCTAssertTrue(generalToggleIDs.contains(.confirmBeforeQuit))
        XCTAssertTrue(generalToggleIDs.contains(.useAlternatingRowBackgrounds))
        XCTAssertTrue(generalToggleIDs.contains(.showFileIcons))
        XCTAssertTrue(generalToggleIDs.contains(.showFileTagColors))
        XCTAssertTrue(generalToggleIDs.contains(.showFileExtensionsSeparately))
        XCTAssertEqual(state.tabs[0].items[0].choiceID, .leftStartupPathMode)
        XCTAssertEqual(state.tabs[0].items[1].choiceID, .rightStartupPathMode)
    }

    func testAppLanguageDefaultsToSystem() {
        let state = SettingsState()

        XCTAssertEqual(state.appLanguage, .system)
        XCTAssertEqual(state.selectedChoice(.appLanguage), .appLanguage(.system))
    }

    func testStartupPathModesDefaultToPreviousPath() {
        let state = SettingsState()

        XCTAssertEqual(state.leftStartupPathMode, .previous)
        XCTAssertEqual(state.rightStartupPathMode, .previous)
        XCTAssertEqual(state.leftStartupPath, "")
        XCTAssertEqual(state.rightStartupPath, "")
        XCTAssertEqual(state.selectedChoice(.leftStartupPathMode), .startupPathMode(.previous))
        XCTAssertEqual(state.selectedChoice(.rightStartupPathMode), .startupPathMode(.previous))
    }

    func testToggleFocusedItemUpdatesMoveCursorAfterMarkingSetting() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "マーク後にカーソルを移動する", toggleID: .moveCursorAfterMarking)
                ])
            ]
        )

        let toggledID = state.toggleFocusedItem()

        XCTAssertEqual(toggledID, .moveCursorAfterMarking)
        XCTAssertFalse(state.movesCursorAfterMarking)
        XCTAssertFalse(state.isToggleOn(.moveCursorAfterMarking))
    }

    func testToggleFocusedItemUpdatesMoveToCreatedFolderSetting() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "作成したフォルダに移動する", toggleID: .moveToCreatedFolder)
                ])
            ]
        )

        let toggledID = state.toggleFocusedItem()

        XCTAssertEqual(toggledID, .moveToCreatedFolder)
        XCTAssertFalse(state.movesToCreatedFolder)
        XCTAssertFalse(state.isToggleOn(.moveToCreatedFolder))
    }

    func testToggleFocusedItemUpdatesConfirmBeforeTrashSetting() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "削除前に確認する", toggleID: .confirmBeforeTrash)
                ])
            ]
        )

        let toggledID = state.toggleFocusedItem()

        XCTAssertEqual(toggledID, .confirmBeforeTrash)
        XCTAssertFalse(state.confirmsBeforeTrash)
        XCTAssertFalse(state.isToggleOn(.confirmBeforeTrash))
    }

    func testToggleFocusedItemUpdatesConfirmBeforeCopySetting() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "コピー前に確認する", toggleID: .confirmBeforeCopy)
                ])
            ]
        )

        let toggledID = state.toggleFocusedItem()

        XCTAssertEqual(toggledID, .confirmBeforeCopy)
        XCTAssertFalse(state.confirmsBeforeCopy)
        XCTAssertFalse(state.isToggleOn(.confirmBeforeCopy))
    }

    func testToggleFocusedItemUpdatesConfirmBeforeMoveSetting() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "移動前に確認する", toggleID: .confirmBeforeMove)
                ])
            ]
        )

        let toggledID = state.toggleFocusedItem()

        XCTAssertEqual(toggledID, .confirmBeforeMove)
        XCTAssertFalse(state.confirmsBeforeMove)
        XCTAssertFalse(state.isToggleOn(.confirmBeforeMove))
    }

    func testToggleFocusedItemUpdatesConfirmBeforeQuitSetting() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "終了前に確認する", toggleID: .confirmBeforeQuit)
                ])
            ]
        )

        let toggledID = state.toggleFocusedItem()

        XCTAssertEqual(toggledID, .confirmBeforeQuit)
        XCTAssertFalse(state.confirmsBeforeQuit)
        XCTAssertFalse(state.isToggleOn(.confirmBeforeQuit))
    }

    func testToggleFocusedItemIgnoresNonToggleItem() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "Startup path")
                ])
            ]
        )

        let toggledID = state.toggleFocusedItem()

        XCTAssertNil(toggledID)
        XCTAssertFalse(state.showsHiddenFiles)
        XCTAssertTrue(state.movesCursorAfterMarking)
        XCTAssertTrue(state.movesToCreatedFolder)
        XCTAssertTrue(state.confirmsBeforeCopy)
        XCTAssertTrue(state.confirmsBeforeMove)
        XCTAssertTrue(state.confirmsBeforeTrash)
        XCTAssertTrue(state.confirmsBeforeQuit)
    }

    func testCycleFocusedChoiceUpdatesAppLanguage() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "Language", choiceID: .appLanguage)
                ])
            ]
        )

        XCTAssertEqual(state.cycleFocusedChoice(), .appLanguage)
        XCTAssertEqual(state.appLanguage, .english)

        XCTAssertEqual(state.cycleFocusedChoice(), .appLanguage)
        XCTAssertEqual(state.appLanguage, .japanese)

        XCTAssertEqual(state.cycleFocusedChoice(), .appLanguage)
        XCTAssertEqual(state.appLanguage, .system)
    }

    func testSetChoiceUpdatesAppLanguageDirectly() {
        var state = SettingsState()

        state.setChoice(.appLanguage, to: .appLanguage(.japanese))

        XCTAssertEqual(state.appLanguage, .japanese)
        XCTAssertEqual(state.selectedChoice(.appLanguage), .appLanguage(.japanese))
    }

    func testStartupPathModeCanBeCycledAndSetDirectly() {
        var state = SettingsState(
            tabs: [
                SettingsTab(title: "General", items: [
                    SettingsItem(title: "Startup path (left)", choiceID: .leftStartupPathMode)
                ])
            ]
        )

        XCTAssertEqual(state.cycleFocusedChoice(), .leftStartupPathMode)
        XCTAssertEqual(state.leftStartupPathMode, .specified)

        state.setChoice(.leftStartupPathMode, to: .startupPathMode(.previous))
        state.setChoice(.rightStartupPathMode, to: .startupPathMode(.specified))

        XCTAssertEqual(state.leftStartupPathMode, .previous)
        XCTAssertEqual(state.rightStartupPathMode, .specified)
    }

    func testSetStartupPathNormalizesOptionalPath() {
        var state = SettingsState()

        state.setStartupPath(" /tmp/./left ", for: .leftStartupPathMode)
        state.setStartupPath("   ", for: .rightStartupPathMode)

        XCTAssertEqual(state.leftStartupPath, "/tmp/left")
        XCTAssertEqual(state.rightStartupPath, "")
    }

    func testJumpPathEntryUsesPathAsListTitleWhenDisplayNameIsEmpty() {
        let entry = JumpPathEntry(displayName: "  ", path: "/tmp/work")

        XCTAssertEqual(entry.listTitle, "/tmp/work")
    }

    func testJumpPathEntryUsesDisplayNameAsListTitleWhenPresent() {
        let entry = JumpPathEntry(displayName: "Work", path: "/tmp/work")

        XCTAssertEqual(entry.listTitle, "Work")
    }

    func testSettingsStateCanAddUpdateAndRemoveJumpPathEntries() {
        var state = SettingsState()

        state.addJumpPath(path: "/tmp/one")
        state.addJumpPath(displayName: "Two", path: "/tmp/two")

        XCTAssertEqual(state.jumpPathEntries, [
            JumpPathEntry(displayName: "", path: "/tmp/one"),
            JumpPathEntry(displayName: "Two", path: "/tmp/two")
        ])

        state.updateJumpPath(at: 0, displayName: "One", path: "/tmp/one-renamed")
        state.removeJumpPath(at: 1)

        XCTAssertEqual(state.jumpPathEntries, [
            JumpPathEntry(displayName: "One", path: "/tmp/one-renamed")
        ])
    }

    func testAddJumpPathIgnoresDuplicatePath() {
        var state = SettingsState()

        XCTAssertTrue(state.addJumpPath(displayName: "One", path: "/tmp/one"))
        XCTAssertFalse(state.addJumpPath(displayName: "Duplicate", path: "/tmp/./one"))

        XCTAssertEqual(state.jumpPathEntries, [
            JumpPathEntry(displayName: "One", path: "/tmp/one")
        ])
    }

    func testMoveJumpPathFocusClampsWithinEntriesAndCanMoveToTabs() {
        var state = SettingsState(jumpPathEntries: [
            JumpPathEntry(path: "/tmp/one"),
            JumpPathEntry(path: "/tmp/two")
        ])

        state.moveJumpPathFocus(by: 10)
        XCTAssertEqual(state.focusedItemIndex, 1)

        state.moveJumpPathFocus(by: -10)
        XCTAssertEqual(state.focusedItemIndex, 0)

        state.moveJumpPathFocus(by: -1)
        XCTAssertEqual(state.focusArea, .tabs)
    }

    func testFocusJumpPathUpdatesFocusWhenIndexExists() {
        var state = SettingsState(jumpPathEntries: [
            JumpPathEntry(path: "/tmp/one"),
            JumpPathEntry(path: "/tmp/two")
        ])

        state.focusJumpPath(at: 1)

        XCTAssertEqual(state.focusedItemIndex, 1)
        XCTAssertEqual(state.focusArea, .items)

        state.focusJumpPath(at: 10)

        XCTAssertEqual(state.focusedItemIndex, 1)
    }

    func testMoveJumpPathReordersEntriesAndMovesFocus() {
        var state = SettingsState(jumpPathEntries: [
            JumpPathEntry(path: "/tmp/one"),
            JumpPathEntry(path: "/tmp/two"),
            JumpPathEntry(path: "/tmp/three")
        ])
        state.focusJumpPath(at: 1)

        state.moveJumpPath(at: state.focusedItemIndex, by: -1)

        XCTAssertEqual(state.jumpPathEntries, [
            JumpPathEntry(path: "/tmp/two"),
            JumpPathEntry(path: "/tmp/one"),
            JumpPathEntry(path: "/tmp/three")
        ])
        XCTAssertEqual(state.focusedItemIndex, 0)
        XCTAssertEqual(state.focusArea, .items)

        state.moveJumpPath(at: state.focusedItemIndex, by: 1)

        XCTAssertEqual(state.jumpPathEntries, [
            JumpPathEntry(path: "/tmp/one"),
            JumpPathEntry(path: "/tmp/two"),
            JumpPathEntry(path: "/tmp/three")
        ])
        XCTAssertEqual(state.focusedItemIndex, 1)
    }

    func testMoveJumpPathClampsAtEdgesAndIgnoresInvalidIndex() {
        var state = SettingsState(jumpPathEntries: [
            JumpPathEntry(path: "/tmp/one"),
            JumpPathEntry(path: "/tmp/two")
        ])

        state.moveJumpPath(at: 0, by: -1)
        XCTAssertEqual(state.jumpPathEntries, [
            JumpPathEntry(path: "/tmp/one"),
            JumpPathEntry(path: "/tmp/two")
        ])
        XCTAssertEqual(state.focusedItemIndex, 0)

        state.moveJumpPath(at: 10, by: 1)
        XCTAssertEqual(state.jumpPathEntries, [
            JumpPathEntry(path: "/tmp/one"),
            JumpPathEntry(path: "/tmp/two")
        ])

        state.moveJumpPath(at: 0, by: 10)
        XCTAssertEqual(state.jumpPathEntries, [
            JumpPathEntry(path: "/tmp/two"),
            JumpPathEntry(path: "/tmp/one")
        ])
        XCTAssertEqual(state.focusedItemIndex, 1)
    }

    func testSettingsStateCanUpdateAndResetKeyBindings() {
        var state = SettingsState()
        let customSequence = KeyBindingSequence(KeyStroke(key: "X"))

        state.addKeyBindingSequence(customSequence, to: .copyMarkedItems)
        XCTAssertTrue(state.keyBindingSet.sequences(for: .copyMarkedItems).contains(customSequence))

        state.resetKeyBindingToDefault(.copyMarkedItems)
        XCTAssertEqual(
            state.keyBindingSet.sequences(for: .copyMarkedItems),
            KeyBindingSet.default.sequences(for: .copyMarkedItems)
        )

        state.addKeyBindingSequence(customSequence, to: .copyMarkedItems)
        state.resetAllKeyBindingsToDefault()
        XCTAssertEqual(state.keyBindingSet, .default)
    }

    func testSettingsStateUpdatesAndCyclesReturnKeyBehavior() {
        var state = SettingsState()

        XCTAssertEqual(state.returnKeyBehavior, .openSelectedDirectory)
        state.setChoice(.returnKeyBehavior, to: .returnKeyBehavior(.previewFileOrOpenDirectory))
        XCTAssertEqual(state.returnKeyBehavior, .previewFileOrOpenDirectory)

        _ = state.cycleFocusedChoice()
        XCTAssertEqual(state.returnKeyBehavior, .previewFileOrOpenDirectory)

        state.focusItem(at: 2)
        XCTAssertEqual(state.cycleFocusedChoice(), .returnKeyBehavior)
        XCTAssertEqual(state.returnKeyBehavior, .disabled)
    }

    func testSettingsStateUpdatesAndCyclesIncrementalSearchMatchMode() {
        var state = SettingsState()

        XCTAssertEqual(state.incrementalSearchMatchMode, .prefix)
        state.setChoice(.incrementalSearchMatchMode, to: .incrementalSearchMatchMode(.contains))
        XCTAssertEqual(state.incrementalSearchMatchMode, .contains)

        state.focusItem(at: 3)
        XCTAssertEqual(state.cycleFocusedChoice(), .incrementalSearchMatchMode)
        XCTAssertEqual(state.incrementalSearchMatchMode, .exact)
    }

    func testDisplayThemeResolvesColorsBySelectionMarkFolderBaseOrder() {
        let theme = DisplayTheme(
            id: "test",
            name: "Test",
            base: DisplayColorPair(
                background: DisplayColor(hex: "#111111"),
                foreground: DisplayColor(hex: "#EEEEEE")
            ),
            selected: DisplayColorPair(background: DisplayColor(hex: "#222222"), foreground: nil),
            marked: DisplayColorPair(background: DisplayColor(hex: "#333333"), foreground: DisplayColor(hex: "#DDDDDD")),
            folder: DisplayColorPair(background: nil, foreground: DisplayColor(hex: "#CCCCCC"))
        )

        XCTAssertEqual(
            theme.resolvedColorPair(isSelected: true, isMarked: true, isDirectory: true),
            DisplayColorPair(background: DisplayColor(hex: "#222222"), foreground: DisplayColor(hex: "#DDDDDD"))
        )
        XCTAssertEqual(
            theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: true),
            DisplayColorPair(background: DisplayColor(hex: "#111111"), foreground: DisplayColor(hex: "#CCCCCC"))
        )
    }

    func testDefaultDisplayThemesHaveEnglishNamesAndStableIDs() {
        XCTAssertEqual(
            DisplayTheme.defaultThemes.map(\.id),
            ["light", "dark", "solarized-light", "solarized-dark", "nord", "dracula"]
        )
        XCTAssertEqual(
            DisplayTheme.defaultThemes.map(\.name),
            ["Light", "Dark", "Solarized Light", "Solarized Dark", "Nord", "Dracula"]
        )
        XCTAssertEqual(DisplayTheme.light.id, "light")
        XCTAssertEqual(DisplayTheme.dark.id, "dark")
        XCTAssertEqual(DisplayThemeSet.protectedThemeIDs, Set(DisplayTheme.defaultThemes.map(\.id)))
    }

    func testDisplayColorDefaultsDecodedAlphaToOpaqueForExistingSettings() throws {
        let data = #"{"red":0.1,"green":0.2,"blue":0.3}"#.data(using: .utf8)!

        let color = try JSONDecoder().decode(DisplayColor.self, from: data)

        XCTAssertEqual(color.red, 0.1)
        XCTAssertEqual(color.green, 0.2)
        XCTAssertEqual(color.blue, 0.3)
        XCTAssertEqual(color.alpha, 1.0)
    }

    func testDisplayColorClampsPaneBackgroundAlpha() {
        XCTAssertEqual(
            DisplayColor(red: 0, green: 0, blue: 0, alpha: 0.1).paneBackgroundAlpha,
            DisplayColor.minimumPaneBackgroundAlpha
        )
        XCTAssertEqual(DisplayColor(red: 0, green: 0, blue: 0, alpha: 2.0).paneBackgroundAlpha, 1.0)
    }

    func testDisplayThemeResolvedColorsPreserveBaseBackgroundAlpha() {
        let theme = DisplayTheme(
            id: "test",
            name: "Test",
            base: DisplayColorPair(
                background: DisplayColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.8),
                foreground: DisplayColor(hex: "#F0F0F0")
            )
        )

        XCTAssertEqual(
            theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false).background?.alpha,
            0.8
        )
    }

    func testDisplayThemeResolvesMessageColorsFromMessageThenBase() {
        let theme = DisplayTheme(
            id: "test",
            name: "Test",
            base: DisplayColorPair(
                background: DisplayColor(hex: "#101010"),
                foreground: DisplayColor(hex: "#F0F0F0")
            ),
            message: DisplayColorPair(background: nil, foreground: DisplayColor(hex: "#AA0000"))
        )

        XCTAssertEqual(
            theme.resolvedMessageColorPair,
            DisplayColorPair(background: DisplayColor(hex: "#101010"), foreground: DisplayColor(hex: "#AA0000"))
        )
    }

    func testDisplayThemeResolvesFocusColorsIndependently() {
        let theme = DisplayTheme(
            id: "test",
            name: "Test",
            base: DisplayColorPair(
                background: DisplayColor(hex: "#101010"),
                foreground: DisplayColor(hex: "#F0F0F0")
            ),
            focus: DisplayColorPair(background: DisplayColor(hex: "#123456"), foreground: nil)
        )

        XCTAssertEqual(
            theme.resolvedFocusColorPair,
            DisplayColorPair(background: DisplayColor(hex: "#123456"), foreground: nil)
        )
    }

    func testSettingsStateCanSelectEditAndAddDisplayTheme() {
        var state = SettingsState()

        state.selectDisplayTheme(id: DisplayTheme.dark.id)
        XCTAssertEqual(state.displayThemeSet.selectedThemeID, DisplayTheme.dark.id)

        XCTAssertFalse(state.displayThemeSet.canEditSelectedTheme)
        XCTAssertFalse(state.displayThemeSet.canDeleteSelectedTheme)

        let unchangedFolderPair = state.displayThemeSet.selectedTheme.folder
        let pair = DisplayColorPair(background: DisplayColor(hex: "#123456"), foreground: nil)
        state.setDisplayColorPair(pair, for: .folder)
        XCTAssertEqual(state.displayThemeSet.selectedTheme.folder, unchangedFolderPair)

        let customTheme = state.addCurrentDisplayTheme(named: "Custom")
        XCTAssertEqual(customTheme.name, "Custom")
        XCTAssertEqual(state.displayThemeSet.selectedThemeID, customTheme.id)
        XCTAssertTrue(state.displayThemeSet.canEditSelectedTheme)
        XCTAssertTrue(state.displayThemeSet.canDeleteSelectedTheme)

        state.setDisplayColorPair(pair, for: .folder)
        XCTAssertEqual(state.displayThemeSet.selectedTheme.folder, pair)

        XCTAssertTrue(state.deleteCurrentDisplayTheme())
        XCTAssertEqual(state.displayThemeSet.selectedThemeID, DisplayTheme.dracula.id)
    }

    func testDisplayThemeUsesEnglishDefaultNameWhenCustomThemeNameIsEmpty() {
        var state = SettingsState()

        let theme = state.addCurrentDisplayTheme(named: "  ")

        XCTAssertEqual(theme.name, "Custom Theme")
        XCTAssertTrue(state.displayThemeSet.canEditSelectedTheme)
    }
}
