import XCTest
@testable import MafxCore

final class PathCompletionServiceTests: XCTestCase {
    func testResolvedDirectoryURLReturnsExistingDirectory() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let service = PathCompletionService()

        XCTAssertEqual(service.resolvedDirectoryURL(for: "target", relativeTo: root), target.standardizedFileURL)
    }

    func testResolvedDirectoryURLRejectsFiles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("file.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data())

        let service = PathCompletionService()

        XCTAssertNil(service.resolvedDirectoryURL(for: "file.txt", relativeTo: root))
    }

    func testCompletedPathCompletesSingleDirectoryMatch() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("Documents", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let service = PathCompletionService()

        XCTAssertEqual(service.completedPath(for: "Doc", relativeTo: root), target.standardizedFileURL.path + "/")
    }

    func testCompletionCandidatesReturnsMultipleMatchesInDisplayOrder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("ProjectAlpha", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("ProjectBeta", isDirectory: true),
            withIntermediateDirectories: true
        )

        let service = PathCompletionService()

        XCTAssertEqual(
            service.completionCandidates(for: "Pro", relativeTo: root),
            [
                root.appendingPathComponent("ProjectAlpha", isDirectory: true).standardizedFileURL.path + "/",
                root.appendingPathComponent("ProjectBeta", isDirectory: true).standardizedFileURL.path + "/"
            ]
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
