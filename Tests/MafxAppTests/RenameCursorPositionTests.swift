@testable import MafxApp
import AppKit
import XCTest

final class RenameCursorPositionTests: XCTestCase {
    func testPlacesCursorBeforeExtension() {
        XCTAssertEqual(renameCursorPosition(for: "archive.tar.gz"), 11)
    }

    func testPlacesCursorAtEndWhenFileNameHasNoExtension() {
        XCTAssertEqual(renameCursorPosition(for: "README"), 6)
    }

    func testUsesUTF16PositionForUnicodeFileName() {
        XCTAssertEqual(renameCursorPosition(for: "😀資料.txt"), 4)
    }

    func testPlacesCursorAtEndForDotFileWithoutExtension() {
        XCTAssertEqual(renameCursorPosition(for: ".gitignore"), 10)
    }

    func testFileNameInputFieldUsesSingleLineHorizontalScrolling() {
        let inputField = makeFileNameInputField(currentName: String(repeating: "a", count: 600))

        XCTAssertEqual(inputField.frame.width, 480)
        XCTAssertTrue(inputField.usesSingleLineMode)
        XCTAssertEqual(inputField.lineBreakMode, .byClipping)
        XCTAssertEqual(inputField.cell?.wraps, false)
        XCTAssertEqual(inputField.cell?.isScrollable, true)
    }
}
