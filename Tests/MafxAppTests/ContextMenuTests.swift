@testable import MafxApp
import AppKit
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
}
