@testable import MafxApp
import AppKit
import XCTest

final class AppMenuTests: XCTestCase {
    func testApplicationMenuTargetsDelegateForAboutAndSettings() {
        let delegate = AppDelegate()
        let applicationMenu = delegate.makeMainMenu().item(at: 0)?.submenu

        XCTAssertTrue(applicationMenu?.item(at: 0)?.target === delegate)
        XCTAssertEqual(applicationMenu?.item(at: 0)?.action, #selector(AppDelegate.showAboutPanel(_:)))
        XCTAssertTrue(applicationMenu?.item(at: 2)?.target === delegate)
        XCTAssertEqual(applicationMenu?.item(at: 2)?.action, #selector(AppDelegate.showSettingsWindow(_:)))
    }

    func testEditMenuProvidesStandardTextEditingCommands() {
        let mainMenu = AppDelegate().makeMainMenu()
        let editMenu = mainMenu.item(at: 1)?.submenu

        XCTAssertEqual(editMenu?.item(at: 0)?.action, #selector(NSText.cut(_:)))
        XCTAssertEqual(editMenu?.item(at: 0)?.keyEquivalent, "x")
        XCTAssertEqual(editMenu?.item(at: 0)?.keyEquivalentModifierMask, .command)
        XCTAssertNil(editMenu?.item(at: 0)?.target)

        XCTAssertEqual(editMenu?.item(at: 1)?.action, #selector(NSText.copy(_:)))
        XCTAssertEqual(editMenu?.item(at: 1)?.keyEquivalent, "c")
        XCTAssertEqual(editMenu?.item(at: 1)?.keyEquivalentModifierMask, .command)
        XCTAssertNil(editMenu?.item(at: 1)?.target)

        XCTAssertEqual(editMenu?.item(at: 2)?.action, #selector(NSText.paste(_:)))
        XCTAssertEqual(editMenu?.item(at: 2)?.keyEquivalent, "v")
        XCTAssertEqual(editMenu?.item(at: 2)?.keyEquivalentModifierMask, .command)
        XCTAssertNil(editMenu?.item(at: 2)?.target)

        XCTAssertEqual(editMenu?.item(at: 4)?.action, #selector(NSText.selectAll(_:)))
        XCTAssertEqual(editMenu?.item(at: 4)?.keyEquivalent, "a")
        XCTAssertEqual(editMenu?.item(at: 4)?.keyEquivalentModifierMask, .command)
        XCTAssertNil(editMenu?.item(at: 4)?.target)
    }

    func testHelpMenuOpensCommandPalette() {
        let delegate = AppDelegate()
        let helpMenu = delegate.makeMainMenu().item(at: 2)?.submenu
        XCTAssertEqual(helpMenu?.item(at: 0)?.action, #selector(AppDelegate.showCommandPalette(_:)))
        XCTAssertTrue(helpMenu?.item(at: 0)?.target === delegate)
    }
}
