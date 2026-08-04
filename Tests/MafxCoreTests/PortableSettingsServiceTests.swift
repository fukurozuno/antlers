import Foundation
import XCTest
@testable import MafxCore

final class PortableSettingsServiceTests: XCTestCase {
    private let service = PortableSettingsJSONService()

    func testExportAndImportRoundTripsPortableSettings() throws {
        var keyBindingSet = KeyBindingSet.default
        keyBindingSet.addSequence(KeyBindingSequence(KeyStroke(key: "X")), to: .copyMarkedItems)
        let state = SettingsState(
            showsHiddenFiles: true,
            usesAlternatingRowBackgrounds: true,
            showsFileIcons: false,
            showsFileTagColors: false,
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
            appLanguage: .english,
            returnKeyBehavior: .previewFileOrOpenDirectory,
            incrementalSearchMatchMode: .contains,
            leftStartupPathMode: .specified,
            rightStartupPathMode: .previous,
            leftStartupPath: temporaryPath("start-left"),
            rightStartupPath: "",
            jumpPathEntries: [
                JumpPathEntry(displayName: "Work", path: temporaryPath("work")),
                JumpPathEntry(displayName: "", path: temporaryPath("missing"))
            ],
            keyBindingSet: keyBindingSet,
            displayThemeSet: DisplayThemeSet(
                selectedThemeID: "custom",
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
            )
        )

        let data = try service.exportData(from: state)
        let imported = try service.importSettingsState(from: data)

        XCTAssertEqual(imported, state)
    }

    func testExportDoesNotContainCurrentPanePathsOrHistories() throws {
        let settings = AppSettings(
            leftStartupPathMode: .specified,
            leftStartupPath: temporaryPath("startup-left"),
            leftPanePath: temporaryPath("current-left"),
            rightPanePath: temporaryPath("current-right"),
            leftPaneNavigationHistory: NavigationHistory(paths: [temporaryPath("history-left")], currentIndex: 0),
            rightPaneNavigationHistory: NavigationHistory(paths: [temporaryPath("history-right")], currentIndex: 0)
        )

        let exportedText = String(data: try service.exportData(from: settings.settingsState), encoding: .utf8)

        XCTAssertNotNil(exportedText)
        XCTAssertTrue(exportedText?.contains("startup-left") == true)
        XCTAssertFalse(exportedText?.contains("current-left") == true)
        XCTAssertFalse(exportedText?.contains("current-right") == true)
        XCTAssertFalse(exportedText?.contains("history-left") == true)
        XCTAssertFalse(exportedText?.contains("history-right") == true)
        XCTAssertFalse(exportedText?.contains("windowFrame") == true)
        XCTAssertFalse(exportedText?.contains("mainWindowFrame") == true)
    }

    func testExportUsesAntlersSettingsFormat() throws {
        let exportedText = String(data: try service.exportData(from: SettingsState()), encoding: .utf8)

        XCTAssertNotNil(exportedText)
        XCTAssertTrue(exportedText?.contains(#""format" : "antlers-settings""#) == true)
        XCTAssertFalse(exportedText?.contains(#""format" : "mafx-settings""#) == true)
        XCTAssertTrue(exportedText?.contains(#""schemaVersion" : 2"#) == true)
    }

    func testImportVersionOneFileTypeAssociationsAsConcreteExtensions() throws {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "fileTypeAssociations": [
              { "id": "00000000-0000-0000-0000-000000000001", "extensions": ["txt"], "applicationPath": "", "color": null }
            ]
          }
        }
        """

        let imported = try service.importSettingsState(from: Data(json.utf8))

        XCTAssertEqual(imported.fileTypeAssociations.map(\.extensions), [["txt"]])
        XCTAssertFalse(imported.fileTypeAssociations[0].matchesOtherExtensions)
    }

    func testImportVersionTwoOtherFileTypeAssociation() throws {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 2,
          "settings": {
            "fileTypeAssociations": [
              { "id": "00000000-0000-0000-0000-000000000001", "extensions": [], "matchesOtherExtensions": true, "applicationPath": "", "color": null }
            ]
          }
        }
        """

        let imported = try service.importSettingsState(from: Data(json.utf8))

        XCTAssertTrue(imported.fileTypeAssociations[0].matchesOtherExtensions)
    }

    func testImportRejectsMultipleOtherFileTypeAssociations() {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 2,
          "settings": {
            "fileTypeAssociations": [
              { "id": "00000000-0000-0000-0000-000000000001", "extensions": [], "matchesOtherExtensions": true, "applicationPath": "", "color": null },
              { "id": "00000000-0000-0000-0000-000000000002", "extensions": [], "matchesOtherExtensions": true, "applicationPath": "", "color": null }
            ]
          }
        }
        """

        XCTAssertThrowsError(try service.importSettingsState(from: Data(json.utf8)))
    }

    func testImportIgnoresUnknownFieldsAndUsesDefaultsForMissingFields() throws {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "showsHiddenFiles": true,
            "unknownSetting": "ignored"
          },
          "unknownTopLevel": {
            "leftPanePath": "/should/not/apply"
          }
        }
        """
        let defaultState = SettingsState(
            movesCursorAfterMarking: false,
            appLanguage: .japanese,
            incrementalSearchMatchMode: .exact
        )

        let imported = try service.importSettingsState(from: Data(json.utf8), defaultState: defaultState)

        XCTAssertTrue(imported.showsHiddenFiles)
        XCTAssertFalse(imported.movesCursorAfterMarking)
        XCTAssertEqual(imported.appLanguage, .japanese)
        XCTAssertEqual(imported.incrementalSearchMatchMode, .exact)
    }

    func testImportAcceptsLegacyMafxSettingsFormat() throws {
        let json = """
        {
          "format": "mafx-settings",
          "schemaVersion": 1,
          "settings": {
            "showsHiddenFiles": true
          }
        }
        """

        let imported = try service.importSettingsState(from: Data(json.utf8))

        XCTAssertTrue(imported.showsHiddenFiles)
    }

    func testImportRejectsDuplicateFileTypeExtensions() {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "fileTypeAssociations": [
              { "id": "00000000-0000-0000-0000-000000000001", "extensions": ["txt"], "applicationPath": "", "color": null },
              { "id": "00000000-0000-0000-0000-000000000002", "extensions": [".TXT"], "applicationPath": "", "color": null }
            ]
          }
        }
        """

        XCTAssertThrowsError(try service.importSettingsState(from: Data(json.utf8))) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Invalid settings file: fileTypeAssociations contains duplicate extensions: txt"
            )
        }
    }

    func testImportKeyBindingSetExtractsOnlyKeyBindings() throws {
        var keyBindingSet = KeyBindingSet.default
        keyBindingSet.addSequence(KeyBindingSequence(KeyStroke(key: "X")), to: .copyMarkedItems)
        let data = try service.exportData(from: SettingsState(
            showsHiddenFiles: true,
            keyBindingSet: keyBindingSet
        ))

        let imported = try service.importKeyBindingSet(from: data)

        XCTAssertEqual(imported, keyBindingSet)
    }

    func testImportKeyBindingSetRejectsFileWithoutKeyBindings() {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "showsHiddenFiles": true
          }
        }
        """

        XCTAssertThrowsError(try service.importKeyBindingSet(from: Data(json.utf8))) { error in
            XCTAssertEqual(error.localizedDescription, "Settings file does not contain keyBindingSet.")
        }
    }

    func testImportDisplayThemeSetExtractsOnlyThemes() throws {
        let theme = DisplayTheme(
            id: "shared-theme",
            name: "Shared Theme",
            base: DisplayColorPair(background: DisplayColor(hex: "#202020"))
        )
        let themeSet = DisplayThemeSet(
            selectedThemeID: theme.id,
            themes: DisplayTheme.defaultThemes + [theme]
        )
        let data = try service.exportData(from: SettingsState(
            showsHiddenFiles: true,
            displayThemeSet: themeSet
        ))

        let imported = try service.importDisplayThemeSet(from: data)

        XCTAssertEqual(imported, themeSet)
    }

    func testImportDisplayThemeSetRejectsFileWithoutThemes() {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "showsHiddenFiles": true
          }
        }
        """

        XCTAssertThrowsError(try service.importDisplayThemeSet(from: Data(json.utf8))) { error in
            XCTAssertEqual(error.localizedDescription, "Settings file does not contain displayThemeSet.")
        }
    }

    func testImportReservesUnmodifiedReturnAndUsesDefaultBehaviorWhenMissing() throws {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "keyBindingSet": {
              "entries": [{
                "commandID": "openSelectedDirectory",
                "context": "mainPane",
                "sequences": [{"strokes": [{"key": "Return", "modifiers": 0}]}]
              }]
            }
          }
        }
        """
        let defaultState = SettingsState(returnKeyBehavior: .disabled)

        let imported = try service.importSettingsState(from: Data(json.utf8), defaultState: defaultState)

        XCTAssertEqual(imported.returnKeyBehavior, .disabled)
        XCTAssertEqual(imported.keyBindingSet.sequences(for: .openSelectedDirectory), [])
    }

    func testImportRejectsUnsupportedFormat() {
        let json = """
        {
          "format": "other-settings",
          "schemaVersion": 1,
          "settings": {}
        }
        """

        XCTAssertThrowsError(try service.importSettingsState(from: Data(json.utf8))) { error in
            guard case PortableSettingsError.unsupportedFormat("other-settings") = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testImportRejectsUnsupportedSchemaVersion() {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 999,
          "settings": {}
        }
        """

        XCTAssertThrowsError(try service.importSettingsState(from: Data(json.utf8))) { error in
            guard case PortableSettingsError.unsupportedSchemaVersion(999) = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testImportRejectsInvalidEnumValues() {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "appLanguage": "fr"
          }
        }
        """

        XCTAssertThrowsError(try service.importSettingsState(from: Data(json.utf8)))
    }

    func testImportRejectsUnsupportedKeyModifiers() {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "keyBindingSet": {
              "entries": [
                {
                  "commandID": "copyMarkedItems",
                  "context": "mainPane",
                  "sequences": [
                    {
                      "strokes": [
                        {
                          "key": "X",
                          "modifiers": 1024
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          }
        }
        """

        XCTAssertThrowsError(try service.importSettingsState(from: Data(json.utf8))) { error in
            guard case PortableSettingsError.invalidSettings = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testImportDoesNotAllowOverridingProtectedDefaultThemes() throws {
        let json = """
        {
          "format": "antlers-settings",
          "schemaVersion": 1,
          "settings": {
            "displayThemeSet": {
              "selectedThemeID": "light",
              "themes": [
                {
                  "id": "light",
                  "name": "Edited Light",
                  "base": {
                    "background": {
                      "red": 0,
                      "green": 0,
                      "blue": 0,
                      "alpha": 1
                    },
                    "foreground": null
                  }
                }
              ]
            }
          }
        }
        """

        let imported = try service.importSettingsState(from: Data(json.utf8))

        XCTAssertEqual(imported.displayThemeSet.selectedThemeID, DisplayTheme.light.id)
        XCTAssertEqual(imported.displayThemeSet.selectedTheme, DisplayTheme.light)
    }

    func testWriteAndReadSettingsFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let url = directory.appendingPathComponent("settings.json")
        let state = SettingsState(showsHiddenFiles: true)

        try service.writeSettings(state, to: url)
        let imported = try service.readSettingsState(from: url)

        XCTAssertEqual(imported, state)
    }

    private func temporaryPath(_ component: String) -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(component)
            .path
    }
}
