import Foundation
import XCTest
@testable import MafxCore

final class CommandPaletteTests: XCTestCase {
    func testEnglishSearchExplainsNameAndKeywordMatchesAlongsideDisplayLanguage() {
        let item = CommandPaletteItem(commandID: .trashSelectedItem, title: "選択項目をゴミ箱へ移動",
                                      category: "ファイル操作", keywords: ["削除"], bindings: ["D"],
                                      englishTitle: "Trash selected item", englishCategory: "File Operation",
                                      englishKeywords: ["delete"])
        XCTAssertEqual(CommandPaletteSearch.results(for: "trash", in: [item]), [item])
        XCTAssertEqual(CommandPaletteSearch.results(for: "削除 delete", in: [item]), [item])
        XCTAssertEqual(CommandPaletteSearch.englishMatchExplanation(for: "trash", in: item),
                       ["Trash selected item"])
        XCTAssertEqual(CommandPaletteSearch.englishMatchExplanation(for: "delete", in: item),
                       ["Trash selected item", "delete"])
        XCTAssertEqual(CommandPaletteSearch.englishMatchExplanation(for: "file", in: item),
                       ["Trash selected item", "File Operation"])
        XCTAssertTrue(CommandPaletteSearch.englishMatchExplanation(for: "削除", in: item).isEmpty)
        XCTAssertTrue(CommandPaletteSearch.englishMatchExplanation(for: "", in: item).isEmpty)
    }

    func testSearchFindsNamesKeywordsAndBindingsWithStableRanking() {
        let items = [
            CommandPaletteItem(commandID: .copyMarkedItems, title: "Copy marked items", category: "File Operation",
                               keywords: ["duplicate"], bindings: ["C"]),
            CommandPaletteItem(commandID: .trashMarkedItems, title: "Trash marked items", category: "File Operation",
                               keywords: ["delete"], bindings: ["D"]),
            CommandPaletteItem(commandID: .copySelectedItem, title: "Copy selected item", category: "File Operation",
                               keywords: ["duplicate"], bindings: [])
        ]

        XCTAssertEqual(CommandPaletteSearch.results(for: "copy", in: items).map(\.commandID),
                       [.copyMarkedItems, .copySelectedItem])
        XCTAssertEqual(CommandPaletteSearch.results(for: "delete", in: items).map(\.commandID),
                       [.trashMarkedItems])
        XCTAssertEqual(CommandPaletteSearch.results(for: "c", in: items).first?.commandID, .copyMarkedItems)
        XCTAssertEqual(CommandPaletteSearch.results(for: "FILE trash", in: items).map(\.commandID),
                       [.trashMarkedItems])
        XCTAssertTrue(CommandPaletteSearch.results(for: "missing", in: items).isEmpty)
    }

    func testUsageHistoryDeduplicatesAndKeepsLatestTenCommands() {
        let commands = Array(CommandID.allCases.prefix(15))
        var history = CommandPaletteUsageHistory()
        for command in commands { history.record(command) }
        XCTAssertEqual(history.entries, Array(commands.suffix(10).reversed()))
        history.record(commands[8])
        XCTAssertEqual(history.entries.first, commands[8])
        XCTAssertEqual(history.entries.count, 10)
        XCTAssertEqual(Set(history.entries.map(\.rawValue)).count, 10)
    }

    func testUsageHistoryRepositoryIgnoresSearchHistoryAndUnknownCommands() throws {
        let suiteName = "CommandPaletteTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(try JSONEncoder().encode(["preview"]), forKey: "commandPalette.searchHistory")
        let repository = CommandPaletteHistoryRepository(defaults: defaults)
        XCTAssertTrue(repository.load().entries.isEmpty)
        var history = CommandPaletteUsageHistory()
        history.record(.previewSelectedFile)
        repository.save(history)
        XCTAssertEqual(repository.load().entries, [.previewSelectedFile])
        XCTAssertNil(defaults.data(forKey: "settings.keyBindingSet"))
        defaults.set(try JSONEncoder().encode(["removedCommand", "openSettings", "openSettings"]),
                     forKey: "commandPalette.usageHistory")
        XCTAssertEqual(repository.load().entries, [.openSettings])
    }

    func testRecentCommandsPrecedeCompleteListAndSearchHidesHistory() {
        let copy = CommandPaletteItem(commandID: .copySelectedItem, title: "Copy", category: "Files",
                                      keywords: [], bindings: [])
        let trash = CommandPaletteItem(commandID: .trashSelectedItem, title: "Trash", category: "Files",
                                       keywords: [], bindings: [])
        let items = [copy, trash]
        let history = CommandPaletteUsageHistory(entries: [.trashSelectedItem, .openSettings])
        XCTAssertEqual(CommandPaletteList.rows(for: "", in: items, history: history),
                       [.heading(.recent), .command(trash), .heading(.all), .command(copy), .command(trash)])
        XCTAssertEqual(CommandPaletteList.rows(for: "copy", in: items, history: history), [.command(copy)])
        XCTAssertEqual(CommandPaletteList.rows(for: "", in: items, history: .init()), items.map { .command($0) })
        XCTAssertEqual(CommandPaletteList.rows(for: "unknown", in: items, history: history), [])
    }

    func testCursorCrossesHistoryBoundaryWithoutSelectingHeadings() {
        let item = CommandPaletteItem(commandID: .openSettings, title: "Settings", category: "Application",
                                      keywords: [], bindings: [])
        let rows = CommandPaletteList.rows(for: "", in: [item], history: .init(entries: [.openSettings]))
        XCTAssertEqual(CommandPaletteList.selection(in: rows, from: -1, moving: 1), 1)
        XCTAssertEqual(CommandPaletteList.selection(in: rows, from: 1, moving: 1), 3)
        XCTAssertEqual(CommandPaletteList.selection(in: rows, from: 3, moving: -1), 1)
        XCTAssertEqual(CommandPaletteList.selection(in: rows, from: 1, moving: -1), 1)
        XCTAssertEqual(CommandPaletteList.selection(in: rows, from: 3, moving: 1), 3)
        XCTAssertNil(CommandPaletteList.selection(in: [], from: -1, moving: 1))
    }

    func testVimPresetKeepsQuestionMarkMenuAndCommandPaletteAlternative() throws {
        let projectDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: projectDirectory.appendingPathComponent("keymap-vim-file-manager.json"))
        let bindings = try PortableSettingsJSONService().importKeyBindingSet(from: data)
        XCTAssertEqual(bindings.sequences(for: .showContextMenu),
                       [.init(.init(key: "?", modifiers: .shift))])
        XCTAssertEqual(bindings.sequences(for: .showCommandPalette),
                       [.init(.init(key: "P", modifiers: [.shift, .command]))])
        XCTAssertTrue(bindings.conflicts().isEmpty, "\(bindings.conflicts())")
    }

    func testExistingCustomBindingTakesPriorityWhenPaletteEntryIsAdded() {
        var existing = KeyBindingSet.default
        existing.entries.removeAll { $0.commandID == .showCommandPalette }
        existing.setSequences([.init(.init(key: "?", modifiers: .shift))], for: .showContextMenu)

        let migrated = existing.fillingMissingDefaultEntries()
        XCTAssertEqual(migrated.sequences(for: .showContextMenu),
                       [.init(.init(key: "?", modifiers: .shift))])
        XCTAssertEqual(migrated.sequences(for: .showCommandPalette),
                       [.init(.init(key: "P", modifiers: [.shift, .command]))])
        XCTAssertTrue(migrated.conflicts().isEmpty)
    }
}
