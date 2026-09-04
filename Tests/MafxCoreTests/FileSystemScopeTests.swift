import Foundation
import XCTest
@testable import MafxCore

final class FileSystemScopeTests: XCTestCase {
    func testConfinedScopeAllowsRootAndDescendants() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = try XCTUnwrap(FileSystemScope(confinedRootURL: root))

        XCTAssertTrue(scope.contains(root))
        XCTAssertTrue(scope.contains(root.appendingPathComponent("child/file.txt")))
        XCTAssertFalse(scope.contains(root.deletingLastPathComponent()))
    }

    func testConfinedScopeRejectsTraversalAndSymlinkEscape() throws {
        let parent = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("root", isDirectory: true)
        let outside = parent.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        let link = root.appendingPathComponent("outside-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let scope = try XCTUnwrap(FileSystemScope(confinedRootURL: root))

        XCTAssertFalse(scope.contains(root.appendingPathComponent("../outside/file.txt")))
        XCTAssertFalse(scope.contains(link.appendingPathComponent("file.txt")))
    }

    func testConfinedScopeRejectsNonDirectoryRoot() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        XCTAssertNil(FileSystemScope(confinedRootURL: file))
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
