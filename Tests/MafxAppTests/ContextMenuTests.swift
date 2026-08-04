@testable import MafxApp
import AppKit
import MafxCore
import XCTest

final class ContextMenuTests: XCTestCase {
    func testContextMenuIncludesCopyPathItem() {
        let viewController = DualPaneViewController()
        let menu = viewController.makeContextMenu()
        let copyPathAction = NSSelectorFromString("copyPathContextMenuItemsToClipboard:")
        let copyPathItem = menu.items.first { $0.action == copyPathAction }

        XCTAssertNotNil(copyPathItem)
        XCTAssertFalse(copyPathItem?.title.isEmpty ?? true)
        XCTAssertTrue(copyPathItem?.target === viewController)
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

    func testParentDirectoryContextMenuIgnoresMarkedOperationTargets() {
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
        XCTAssertFalse(item(in: menu, action: "copyContextMenuItems:")?.isEnabled ?? true)
        XCTAssertFalse(item(in: menu, action: "moveContextMenuItems:")?.isEnabled ?? true)
    }

    private func item(in menu: NSMenu, action selectorName: String) -> NSMenuItem? {
        let action = NSSelectorFromString(selectorName)
        return menu.items.first { $0.action == action }
    }
}
