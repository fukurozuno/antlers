import Foundation
import XCTest
@testable import MafxCore

final class DirectoryListingServiceTests: XCTestCase {
    func testContentsIncludesFileByteSize() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = temporaryDirectory.appendingPathComponent("file.bin")
        let fileData = Data([0, 1, 2, 3, 4])

        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try fileData.write(to: fileURL)

        let service = DirectoryListingService()
        let contents = try service.contents(of: temporaryDirectory)

        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(contents.first?.name, fileURL.lastPathComponent)
        XCTAssertEqual(contents.first?.isDirectory, false)
        XCTAssertEqual(contents.first?.byteSize, Int64(fileData.count))
    }

    func testContentsSkipsHiddenFilesByDefault() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let visibleFile = temporaryDirectory.appendingPathComponent("visible.txt")
        let hiddenFile = temporaryDirectory.appendingPathComponent(".hidden")

        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try Data().write(to: visibleFile)
        try Data().write(to: hiddenFile)

        let service = DirectoryListingService()
        let contents = try service.contents(of: temporaryDirectory)

        XCTAssertEqual(contents.map(\.name), ["visible.txt"])
    }

    func testContentsIncludesHiddenFilesWhenRequested() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let visibleFile = temporaryDirectory.appendingPathComponent("visible.txt")
        let hiddenFile = temporaryDirectory.appendingPathComponent(".hidden")

        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try Data().write(to: visibleFile)
        try Data().write(to: hiddenFile)

        let service = DirectoryListingService()
        let contents = try service.contents(of: temporaryDirectory, includingHiddenFiles: true)

        XCTAssertEqual(contents.map(\.name), [".hidden", "visible.txt"])
    }
}
