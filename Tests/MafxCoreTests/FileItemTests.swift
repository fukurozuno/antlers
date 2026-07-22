import Foundation
import XCTest
@testable import MafxCore

final class FileItemTests: XCTestCase {
    func testDisplayNameSplitsOnlyTheFinalExtension() {
        let item = fileItem(named: "0000.1111.2222.3333.444455556666")

        XCTAssertEqual(item.displayBaseName, "0000.1111.2222.3333")
        XCTAssertEqual(item.fileExtension, "444455556666")
        XCTAssertEqual(item.displayFileExtension, ".444455556666")
    }

    func testDisplayNameKeepsSingleLeadingDotFileIntact() {
        let item = fileItem(named: ".gitignore")

        XCTAssertEqual(item.displayBaseName, ".gitignore")
        XCTAssertEqual(item.fileExtension, "")
        XCTAssertEqual(item.displayFileExtension, "")
    }

    func testDisplayNameSplitsAHiddenFileWithAnotherDot() {
        let item = fileItem(named: ".config.json")

        XCTAssertEqual(item.displayBaseName, ".config")
        XCTAssertEqual(item.fileExtension, "json")
        XCTAssertEqual(item.displayFileExtension, ".json")
    }

    func testDisplayNameKeepsTrailingDotWhenThereIsNoExtension() {
        let item = fileItem(named: "file.")

        XCTAssertEqual(item.displayBaseName, "file.")
        XCTAssertEqual(item.fileExtension, "")
        XCTAssertEqual(item.displayFileExtension, "")
    }

    func testDirectoriesAndParentDirectoryDoNotHaveExtensions() {
        let directory = FileItem(url: URL(fileURLWithPath: "/tmp/sample.app"), isDirectory: true)
        let parent = FileItem.parentDirectoryItem(for: URL(fileURLWithPath: "/tmp/child", isDirectory: true))!

        XCTAssertEqual(directory.displayBaseName, "sample.app")
        XCTAssertEqual(directory.fileExtension, "")
        XCTAssertEqual(parent.fileExtension, "")
    }

    private func fileItem(named name: String) -> FileItem {
        FileItem(url: URL(fileURLWithPath: "/tmp/\(name)"), isDirectory: false)
    }
}
