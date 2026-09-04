@testable import MafxApp
import AppKit
import MafxCore
import XCTest

final class ContextMenuTests: XCTestCase {
    func testOperationMenuActivatesSelectedEntryAndNavigatesChildren() {
        let child = OperationMenuEntry(title: "Child")
        let parent = OperationMenuEntry(title: "Parent", children: [child])
        let entry = OperationMenuEntry(title: "Entry", commandID: .copyMarkedItems)
        let menu = OperationMenuOverlayView(entries: [entry, parent], keyBindingSet: .default, theme: .light)
        var activatedTitle: String?
        menu.onEntryActivated = { activatedTitle = $0.title }

        menu.activateSelection()
        XCTAssertEqual(activatedTitle, "Entry")

        menu.moveSelection(by: 1)
        menu.activateSelection()
        XCTAssertEqual(menu.currentEntries.map(\.title), ["Child"])
        XCTAssertTrue(menu.goBack())
        XCTAssertEqual(menu.currentEntries.map(\.title), ["Entry", "Parent"])
    }

    func testOperationMenuFocusesFirstEnabledEntryByInitialCharacter() {
        let disabled = OperationMenuEntry(title: "Preview", isEnabled: false)
        let preview = OperationMenuEntry(title: "Photos")
        let safari = OperationMenuEntry(title: "Safari")
        let menu = OperationMenuOverlayView(entries: [disabled, preview, safari], keyBindingSet: .default, theme: .light)
        var activatedTitle: String?
        menu.onEntryActivated = { activatedTitle = $0.title }

        XCTAssertTrue(menu.focusFirstEnabledEntry(startingWith: "p"))
        menu.activateSelection()

        XCTAssertEqual(activatedTitle, "Photos")
    }

    func testOperationMenuDisplaysBindingForEntryWithChildren() {
        var keyBindingSet = KeyBindingSet.default
        keyBindingSet.setSequences([.init(.init(key: "O", modifiers: .option))], for: .showOpenWithMenu)
        let entry = OperationMenuEntry(
            title: "Open With",
            commandID: .showOpenWithMenu,
            children: [OperationMenuEntry(title: "Preview")]
        )
        let menu = OperationMenuOverlayView(entries: [entry], keyBindingSet: keyBindingSet, theme: .light)

        XCTAssertEqual(menu.shortcutDisplayText(for: entry), "Option+O")
    }

    func testContextMenuIncludesCopyPathItem() {
        let viewController = DualPaneViewController()
        let menu = viewController.makeContextMenu()
        let copyPathAction = NSSelectorFromString("copyPathContextMenuItemsToClipboard:")
        let copyPathItem = menu.items.first { $0.action == copyPathAction }

        XCTAssertNotNil(copyPathItem)
        XCTAssertFalse(copyPathItem?.title.isEmpty ?? true)
        XCTAssertTrue(copyPathItem?.target === viewController)
        XCTAssertEqual(copyPathItem?.title, L10n.string("contextMenu.copyPath"))
        XCTAssertEqual(copyPathItem?.keyEquivalent, "")
    }

    func testContextMenuDoesNotShowKeyBinding() {
        var keyBindingSet = KeyBindingSet.default
        keyBindingSet.setSequences([.init(.init(key: "X"))], for: .copyMarkedItems)
        let settings = AppSettings(
            leftPanePath: "/tmp/context-menu/left",
            rightPanePath: "/tmp/context-menu/right",
            keyBindingSet: keyBindingSet
        )
        let viewController = DualPaneViewController(settings: settings)
        let menu = viewController.makeContextMenu()
        let copyItem = item(in: menu, action: "copyContextMenuItems:")

        XCTAssertEqual(copyItem?.title, L10n.string("contextMenu.copy"))
        XCTAssertEqual(copyItem?.keyEquivalent, "")
        XCTAssertFalse(copyItem?.isEnabled ?? true)
    }

    func testContextMenuDoesNotDisplayMultipleBindings() {
        var keyBindingSet = KeyBindingSet.default
        keyBindingSet.setSequences(
            [
                .init(.init(key: "X")),
                .init(.init(key: "Y"))
            ],
            for: .copyMarkedItems
        )
        let settings = AppSettings(
            leftPanePath: "/tmp/context-menu/left",
            rightPanePath: "/tmp/context-menu/right",
            keyBindingSet: keyBindingSet
        )
        let viewController = DualPaneViewController(settings: settings)
        let menu = viewController.makeContextMenu()

        XCTAssertEqual(item(in: menu, action: "copyContextMenuItems:")?.title, L10n.string("contextMenu.copy"))
    }

    func testContextMenuProvidesMarkAndTrashCommandsForMarkedItems() {
        let currentDirectory = URL(fileURLWithPath: "/tmp/context-menu/current")
        let markedURL = currentDirectory.appendingPathComponent("marked.txt")
        let state = PaneState(
            currentDirectory: currentDirectory,
            items: [FileItem(url: markedURL, isDirectory: false)],
            markedItemURLs: [markedURL]
        )
        let viewController = DualPaneViewController()
        let menu = viewController.makeContextMenu(for: state)

        XCTAssertNotNil(item(in: menu, action: "toggleMarkContextMenuItem:"))
        XCTAssertTrue(item(in: menu, action: "clearMarksContextMenuItem:")?.isEnabled ?? false)
        XCTAssertEqual(item(in: menu, action: "clearMarksContextMenuItem:")?.title, L10n.string("contextMenu.clearMarks"))
        XCTAssertEqual(item(in: menu, action: "clearMarksContextMenuItem:")?.keyEquivalent, "")
        XCTAssertTrue(item(in: menu, action: "copyContextMenuItems:")?.isEnabled ?? false)
        XCTAssertTrue(item(in: menu, action: "moveContextMenuItems:")?.isEnabled ?? false)
        XCTAssertTrue(item(in: menu, action: "trashContextMenuItems:")?.isEnabled ?? false)
        XCTAssertNotNil(item(in: menu, action: "invertFileMarksContextMenuItem:"))
        XCTAssertNotNil(item(in: menu, action: "invertFileAndDirectoryMarksContextMenuItem:"))
    }

    func testContextMenuSeparatesSelectedItemOperationsFromMarkedItemOperations() {
        let currentDirectory = URL(fileURLWithPath: "/tmp/context-menu/current")
        let selectedURL = currentDirectory.appendingPathComponent("selected.txt")
        let state = PaneState(
            currentDirectory: currentDirectory,
            items: [FileItem(url: selectedURL, isDirectory: false)]
        )
        let viewController = DualPaneViewController()
        let menu = viewController.makeContextMenu(for: state)

        XCTAssertTrue(item(in: menu, action: "copySelectedContextMenuItem:")?.isEnabled ?? false)
        XCTAssertTrue(item(in: menu, action: "moveSelectedContextMenuItem:")?.isEnabled ?? false)
        XCTAssertTrue(item(in: menu, action: "trashSelectedContextMenuItem:")?.isEnabled ?? false)
        XCTAssertFalse(item(in: menu, action: "copyContextMenuItems:")?.isEnabled ?? true)
        XCTAssertFalse(item(in: menu, action: "moveContextMenuItems:")?.isEnabled ?? true)
        XCTAssertFalse(item(in: menu, action: "trashContextMenuItems:")?.isEnabled ?? true)
    }

    func testParentDirectoryContextMenuEnablesOnlyCurrentPathActions() {
        let currentDirectory = URL(fileURLWithPath: "/tmp/context-menu/current")
        guard let parentItem = FileItem.parentDirectoryItem(for: currentDirectory) else {
            return XCTFail("Expected a parent directory item")
        }
        let state = PaneState(currentDirectory: currentDirectory, items: [parentItem])
        let viewController = DualPaneViewController()
        let menu = viewController.makeContextMenu(for: state)

        XCTAssertFalse(menu.autoenablesItems)
        XCTAssertFalse(item(in: menu, action: "openSelectedContextMenuItem:")?.isEnabled ?? true)
        XCTAssertFalse(menu.items.first { $0.title == L10n.string("contextMenu.openWith") }?.isEnabled ?? true)
        XCTAssertTrue(item(in: menu, action: "revealSelectedContextMenuItemInFinder:")?.isEnabled ?? false)
        XCTAssertTrue(item(in: menu, action: "copyPathContextMenuItemsToClipboard:")?.isEnabled ?? false)
        XCTAssertFalse(item(in: menu, action: "copyContextMenuItems:")?.isEnabled ?? true)
        XCTAssertFalse(item(in: menu, action: "moveContextMenuItems:")?.isEnabled ?? true)
        XCTAssertFalse(item(in: menu, action: "renameContextMenuItem:")?.isEnabled ?? true)
        XCTAssertFalse(item(in: menu, action: "copyContextMenuItemWithNewName:")?.isEnabled ?? true)
    }

    func testParentDirectoryContextMenuUsesMarkedOperationTargets() {
        let currentDirectory = URL(fileURLWithPath: "/tmp/context-menu/current")
        guard let parentItem = FileItem.parentDirectoryItem(for: currentDirectory) else {
            return XCTFail("Expected a parent directory item")
        }
        let markedURL = currentDirectory.appendingPathComponent("marked.txt")
        let state = PaneState(
            currentDirectory: currentDirectory,
            items: [
                parentItem,
                FileItem(url: markedURL, isDirectory: false)
            ],
            markedItemURLs: [markedURL]
        )
        let viewController = DualPaneViewController()
        let menu = viewController.makeContextMenu(for: state)

        XCTAssertTrue(item(in: menu, action: "copyPathContextMenuItemsToClipboard:")?.isEnabled ?? false)
        XCTAssertTrue(item(in: menu, action: "copyContextMenuItems:")?.isEnabled ?? false)
        XCTAssertTrue(item(in: menu, action: "moveContextMenuItems:")?.isEnabled ?? false)
        XCTAssertTrue(item(in: menu, action: "trashContextMenuItems:")?.isEnabled ?? false)
    }

    private func item(in menu: NSMenu, action selectorName: String) -> NSMenuItem? {
        let action = NSSelectorFromString(selectorName)
        return menu.items.first { $0.action == action }
    }

}
