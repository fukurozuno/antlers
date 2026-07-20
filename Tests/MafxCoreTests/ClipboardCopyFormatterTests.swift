import XCTest
@testable import MafxCore

final class ClipboardCopyFormatterTests: XCTestCase {
    func testFormatsItemsForEachClipboardCopyFormat() {
        let root = URL(fileURLWithPath: "/tmp/clipboard-test")
        let first = FileItem(url: root.appendingPathComponent("first.txt"), isDirectory: false)
        let second = FileItem(url: root.appendingPathComponent("folder"), isDirectory: true)

        XCTAssertEqual(ClipboardCopyFormat.fileName.text(for: [first, second], in: root), "first.txt\nfolder")
        XCTAssertEqual(ClipboardCopyFormat.directoryPath.text(for: [first, second], in: root), "/tmp/clipboard-test\n/tmp/clipboard-test")
        XCTAssertEqual(ClipboardCopyFormat.fullPath.text(for: [first, second], in: root), "/tmp/clipboard-test/first.txt\n/tmp/clipboard-test/folder")
    }

    func testFileNameFormatCopiesParentDirectoryItemAsEmptyText() {
        let currentDirectory = URL(fileURLWithPath: "/tmp/clipboard-test/current")
        let parentItem = FileItem.parentDirectoryItem(for: currentDirectory)

        guard let parentItem else {
            return XCTFail("Expected a parent directory item")
        }

        XCTAssertEqual(ClipboardCopyFormat.fileName.text(for: [parentItem], in: currentDirectory), "")
        XCTAssertEqual(ClipboardCopyFormat.directoryPath.text(for: [parentItem], in: currentDirectory), currentDirectory.path)
        XCTAssertEqual(ClipboardCopyFormat.fullPath.text(for: [parentItem], in: currentDirectory), currentDirectory.path)
    }
}
