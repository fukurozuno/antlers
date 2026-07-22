import Foundation
import XCTest
@testable import MafxCore

final class FileInfoServiceTests: XCTestCase {
    func testInfoForFileUsesListingMetadata() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = temporaryDirectory.appendingPathComponent("file.bin")
        let modificationDate = Date(timeIntervalSince1970: 1_700_000_000)

        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try Data([0, 1, 2]).write(to: fileURL)

        let item = FileItem(
            url: fileURL,
            isDirectory: false,
            byteSize: 3,
            modificationDate: modificationDate
        )
        let info = try FileInfoService().info(for: item)

        XCTAssertEqual(info.name, "file.bin")
        XCTAssertEqual(info.url, fileURL)
        XCTAssertFalse(info.isDirectory)
        XCTAssertEqual(info.byteSize, 3)
        XCTAssertEqual(info.modificationDate, modificationDate)
        XCTAssertNil(info.directorySize)
    }

    func testInfoForDirectoryCalculatesRecursiveByteSize() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let childDirectory = temporaryDirectory.appendingPathComponent("child", isDirectory: true)

        try FileManager.default.createDirectory(at: childDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try Data([0, 1, 2]).write(to: temporaryDirectory.appendingPathComponent("a.bin"))
        try Data([3, 4]).write(to: childDirectory.appendingPathComponent("b.bin"))

        let item = FileItem(url: temporaryDirectory, isDirectory: true)
        let info = try FileInfoService().info(for: item)

        XCTAssertEqual(info.directorySize, DirectorySize(byteSize: 5))
    }

    func testDirectorySizeDoesNotFollowSymbolicLinkDirectories() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let targetDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let linkURL = temporaryDirectory.appendingPathComponent("link")

        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            try? FileManager.default.removeItem(at: targetDirectory)
        }
        try Data([0, 1, 2, 3]).write(to: targetDirectory.appendingPathComponent("linked.bin"))
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetDirectory)

        let item = FileItem(url: temporaryDirectory, isDirectory: true)
        let info = try FileInfoService().info(for: item)

        XCTAssertEqual(info.directorySize, DirectorySize(byteSize: 0))
    }
}
