@testable import MafxApp
import AppKit
import MafxCore
import XCTest

final class KeyBindingSettingsUITests: XCTestCase {
    func testFunctionAndKeySearchFilterCommandsInKeybindingsTab() {
        var state = SettingsState()
        let tabIndex = state.tabs.firstIndex { $0.title == "Keybindings" }!
        state.selectTab(at: tabIndex)
        let controller = SettingsWindowController(settings: state)
        guard let window = controller.window, let contentView = window.contentView else {
            return XCTFail("Settings window was not created")
        }
        contentView.layoutSubtreeIfNeeded()

        let views = descendants(of: contentView)
        guard let searchField = views.compactMap({ $0 as? NSSearchField }).first,
              let commandTable = views.compactMap({ $0 as? NSTableView })
                .first(where: { $0.tableColumns.count == 4 }) else {
            return XCTFail("Keybinding search controls were not created")
        }
        XCTAssertFalse(searchField.isHidden)
        XCTAssertEqual(commandTable.numberOfRows, CommandID.allCases.count)

        searchField.stringValue = "sort by size"
        searchField.delegate?.controlTextDidChange?(
            Notification(name: NSControl.textDidChangeNotification, object: searchField)
        )
        XCTAssertEqual(commandTable.numberOfRows, 1)

        let buttons = views.compactMap { $0 as? NSButton }
        guard let clearButton = buttons.first(where: { $0.title == L10n.string("settings.button.clearSearch") }),
              let keySearchButton = buttons.first(where: { $0.title == L10n.string("settings.button.searchByKey") }) else {
            return XCTFail("Key search buttons were not created")
        }
        clearButton.performClick(nil)
        keySearchButton.performClick(nil)
        let captureView = contentView.subviews.last!
        XCTAssertFalse(captureView.isHidden)
        XCTAssertFalse(searchField.isEnabled)
        XCTAssertFalse(clearButton.isEnabled)
        XCTAssertFalse(keySearchButton.isEnabled)
        XCTAssertTrue(commandTable.isEnabled)
        XCTAssertTrue(clearButton.superview!.isHidden)
        let prominentKey = descendants(of: captureView).compactMap { $0 as? NSTextField }
            .first { $0.font?.pointSize == 34 }
        XCTAssertNotNil(prominentKey)
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil,
                                     characters: "S", charactersIgnoringModifiers: "S", isARepeat: false, keyCode: 1)!
        captureView.keyDown(with: event)
        let expectedCommands = Set(KeyBindingSet.default.bindings(startingWith: [.init(key: "S")])
            .map { $0.commandID })
        XCTAssertEqual(commandTable.numberOfRows, expectedCommands.count)
        XCTAssertEqual(prominentKey?.stringValue, "S")
        XCTAssertTrue(descendants(of: captureView).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue.contains("\(expectedCommands.count)") })
        let returnEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                           windowNumber: window.windowNumber, context: nil,
                                           characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false,
                                           keyCode: 36)!
        captureView.keyDown(with: returnEvent)
        XCTAssertFalse(captureView.isHidden)
        XCTAssertEqual(commandTable.numberOfRows, expectedCommands.count)
        commandTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        XCTAssertTrue(NSApp.sendAction(commandTable.action!, to: commandTable.target, from: commandTable))
        XCTAssertTrue(captureView.isHidden)
        XCTAssertTrue(searchField.isEnabled)
        XCTAssertEqual(commandTable.numberOfRows, CommandID.allCases.count)

        keySearchButton.performClick(nil)
        let freeKey = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .control, timestamp: 0,
                                       windowNumber: window.windowNumber, context: nil,
                                       characters: "u", charactersIgnoringModifiers: "u", isARepeat: false,
                                       keyCode: 32)!
        captureView.keyDown(with: freeKey)
        XCTAssertEqual(commandTable.numberOfRows, 1)
        let commandColumn = commandTable.column(withIdentifier: NSUserInterfaceItemIdentifier("command"))
        let emptyRow = commandTable.view(atColumn: commandColumn, row: 0, makeIfNecessary: true)!
        XCTAssertTrue(descendants(of: emptyRow).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue == L10n.string("settings.unassigned") })
        XCTAssertTrue(descendants(of: contentView).compactMap { $0 as? NSButton }
            .contains { $0.title == L10n.string("settings.button.assignCommand") && !$0.isHidden && $0.isEnabled })

        let escapeEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                           windowNumber: window.windowNumber, context: nil,
                                           characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                           isARepeat: false, keyCode: 53)!
        captureView.keyDown(with: escapeEvent)
        XCTAssertTrue(captureView.isHidden)
        XCTAssertEqual(commandTable.numberOfRows, CommandID.allCases.count)
    }

    func testAssignmentPickerUsesCommandPaletteSearch() {
        let picker = KeyBindingAssignmentPicker(excluding: .sortByName, bindings: .default)
        picker.searchField.stringValue = "sort by size"
        picker.searchField.delegate?.controlTextDidChange?(
            Notification(name: NSControl.textDidChangeNotification, object: picker.searchField)
        )
        XCTAssertEqual(picker.selectedCommandID, .sortBySize)
        XCTAssertEqual(picker.tableView.numberOfRows, 1)

        picker.searchField.stringValue = "no such command"
        picker.searchField.delegate?.controlTextDidChange?(
            Notification(name: NSControl.textDidChangeNotification, object: picker.searchField)
        )
        XCTAssertNil(picker.selectedCommandID)
        XCTAssertEqual(picker.tableView.numberOfRows, 0)
    }

    func testExactKeySearchShowsKeyActionsAndStaysActiveUntilSelection() {
        var state = SettingsState()
        state.selectTab(at: state.tabs.firstIndex { $0.title == "Keybindings" }!)
        let controller = SettingsWindowController(settings: state)
        guard let window = controller.window, let contentView = window.contentView else {
            return XCTFail("Settings window was not created")
        }
        let searchButton = descendants(of: contentView).compactMap { $0 as? NSButton }
            .first { $0.title == L10n.string("settings.button.searchByKey") }!
        let commandTable = descendants(of: contentView).compactMap { $0 as? NSTableView }
            .first { $0.tableColumns.count == 4 }!
        let captureView = contentView.subviews.last!
        searchButton.performClick(nil)
        let stroke = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                      windowNumber: window.windowNumber, context: nil,
                                      characters: "S", charactersIgnoringModifiers: "S", isARepeat: false,
                                      keyCode: 1)!
        captureView.keyDown(with: stroke)
        captureView.keyDown(with: stroke)
        XCTAssertEqual(commandTable.numberOfRows, 1)
        let buttons = descendants(of: contentView).compactMap { $0 as? NSButton }
        let reassign = buttons.first { $0.title == L10n.string("settings.button.reassignKey") }!
        let remove = buttons.first { $0.title == L10n.string("settings.button.removeSearchedKey") }!
        XCTAssertFalse(reassign.superview!.isHidden)
        XCTAssertFalse(remove.isHidden)

        let enter = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil,
                                     characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false,
                                     keyCode: 36)!
        captureView.keyDown(with: enter)
        XCTAssertFalse(captureView.isHidden)
        remove.performClick(nil)
        XCTAssertEqual(commandTable.numberOfRows, 1)
        XCTAssertTrue(window.firstResponder === captureView)
        let commandColumn = commandTable.column(withIdentifier: NSUserInterfaceItemIdentifier("command"))
        let resultCell = commandTable.view(atColumn: commandColumn, row: 0, makeIfNecessary: true)!
        XCTAssertTrue(descendants(of: resultCell).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue == L10n.string("settings.unassigned") })
        XCTAssertTrue(buttons.contains { $0.title == L10n.string("settings.button.assignCommand") })
    }

    func testFunctionDetailsOfferPerKeyRemovalAndHideNormalStatus() {
        var state = SettingsState()
        state.selectTab(at: state.tabs.firstIndex { $0.title == "Keybindings" }!)
        let controller = SettingsWindowController(settings: state)
        guard let contentView = controller.window?.contentView else {
            return XCTFail("Settings window was not created")
        }
        let tables = descendants(of: contentView).compactMap { $0 as? NSTableView }
        let commandTable = tables.first { $0.tableColumns.count == 4 }!
        let detailTable = tables.first { $0.tableColumns.count == 1 }!
        contentView.layoutSubtreeIfNeeded()
        XCTAssertTrue(descendants(of: contentView).compactMap { $0 as? NSButton }
            .contains { $0.title == L10n.string("settings.button.addBinding") })
        XCTAssertFalse(descendants(of: contentView).compactMap { $0 as? NSButton }
            .contains { $0.title == L10n.string("settings.button.moveBinding") })
        let moreButton = descendants(of: contentView).compactMap { $0 as? NSPopUpButton }
            .first { $0.itemTitles.contains(L10n.string("settings.button.resetAll")) }!
        XCTAssertEqual(detailTable.enclosingScrollView?.frame.height ?? 0, 28, accuracy: 1)
        let statusColumn = commandTable.column(withIdentifier: NSUserInterfaceItemIdentifier("status"))
        let statusCell = commandTable.view(atColumn: statusColumn, row: 0, makeIfNecessary: true)!
        XCTAssertTrue(descendants(of: statusCell).compactMap { $0 as? NSTextField }
            .allSatisfy { $0.stringValue.isEmpty })
        let detailCell = detailTable.view(atColumn: 0, row: 0, makeIfNecessary: true)!
        let remove = descendants(of: detailCell).compactMap { $0 as? NSButton }.first { $0.title == "−" }!
        remove.performClick(nil)
        let bindingsColumn = commandTable.column(withIdentifier: NSUserInterfaceItemIdentifier("bindings"))
        let bindingsCell = commandTable.view(atColumn: bindingsColumn, row: 0, makeIfNecessary: true)!
        XCTAssertTrue(descendants(of: bindingsCell).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue == L10n.string("settings.unassigned") })
        let resetCommand = moreButton.item(at: 1)!
        XCTAssertTrue(NSApp.sendAction(resetCommand.action!, to: resetCommand.target, from: resetCommand))
        let restoredCell = commandTable.view(atColumn: bindingsColumn, row: 0, makeIfNecessary: true)!
        XCTAssertFalse(descendants(of: restoredCell).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue == L10n.string("settings.unassigned") })
    }

    func testRecordingDisplaysTargetAndEachStrokeProminently() {
        var state = SettingsState()
        state.selectTab(at: state.tabs.firstIndex { $0.title == "Keybindings" }!)
        let controller = SettingsWindowController(settings: state)
        guard let window = controller.window, let contentView = window.contentView else {
            return XCTFail("Settings window was not created")
        }
        contentView.layoutSubtreeIfNeeded()
        let captureView = contentView.subviews.last!
        let views = descendants(of: contentView)
        guard let recordButton = views.compactMap({ $0 as? NSButton })
            .first(where: { $0.title == L10n.string("settings.button.addBinding") }),
              let commandTable = views.compactMap({ $0 as? NSTableView })
                .first(where: { $0.tableColumns.count == 4 }) else {
            return XCTFail("Recording controls were not created")
        }

        let searchField = views.compactMap { $0 as? NSSearchField }.first!
        searchField.stringValue = CommandID.moveSelectionUp.localizedTitle
        searchField.delegate?.controlTextDidChange?(
            Notification(name: NSControl.textDidChangeNotification, object: searchField)
        )
        XCTAssertEqual(commandTable.numberOfRows, 1)
        recordButton.performClick(nil)
        XCTAssertEqual(searchField.stringValue, CommandID.moveSelectionUp.localizedTitle)
        XCTAssertFalse(captureView.isHidden)
        XCTAssertFalse(recordButton.isEnabled)
        XCTAssertFalse(views.compactMap { $0 as? NSSearchField }.first!.isEnabled)
        XCTAssertTrue(descendants(of: captureView).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue.contains(CommandID.moveSelectionUp.localizedTitle) })
        let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .control, timestamp: 0,
                                   windowNumber: window.windowNumber, context: nil,
                                   characters: "u", charactersIgnoringModifiers: "u", isARepeat: false,
                                   keyCode: 32)!
        captureView.keyDown(with: key)
        XCTAssertTrue(descendants(of: captureView).compactMap { $0 as? NSTextField }
            .contains { $0.font?.pointSize == 34 && $0.stringValue == "Control+U" })
        XCTAssertTrue(window.firstResponder === captureView)

        let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                      windowNumber: window.windowNumber, context: nil,
                                      characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                      isARepeat: false, keyCode: 53)!
        captureView.keyDown(with: escape)
        XCTAssertTrue(captureView.isHidden)
        XCTAssertTrue(recordButton.isEnabled)
        XCTAssertTrue(window.firstResponder === commandTable)

        recordButton.performClick(nil)
        captureView.keyDown(with: key)
        let enter = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil,
                                     characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false,
                                     keyCode: 36)!
        captureView.keyDown(with: enter)
        XCTAssertTrue(captureView.isHidden)
        XCTAssertTrue(recordButton.isEnabled)
        let bindingsColumn = commandTable.column(withIdentifier: NSUserInterfaceItemIdentifier("bindings"))
        let bindingsCell = commandTable.view(atColumn: bindingsColumn, row: 0, makeIfNecessary: true)!
        XCTAssertTrue(descendants(of: bindingsCell).compactMap { $0 as? NSTextField }
            .contains { $0.stringValue.contains("Control+U") })
    }

    private func descendants(of view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }
}
