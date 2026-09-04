import Foundation
import XCTest
import ZIPFoundation
@testable import MafxCore

final class ArchiveServiceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testCreateZIPListsEntriesAndExtractsToNewDirectory() throws {
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let nestedDirectory = sourceDirectory.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: sourceDirectory.appendingPathComponent("a.txt"))
        try Data("world".utf8).write(to: nestedDirectory.appendingPathComponent("b.txt"))

        let archiveURL = temporaryDirectory.appendingPathComponent("source.zip")
        let service = ArchiveService()
        try service.createZIP(from: [sourceDirectory], to: archiveURL)

        let entries = try service.entries(in: archiveURL)
        XCTAssertEqual(Set(entries.map(\.path)), Set(["source/", "source/a.txt", "source/nested/", "source/nested/b.txt"]))

        let destinationURL = temporaryDirectory.appendingPathComponent("expanded", isDirectory: true)
        let result = try service.extractZIP(at: archiveURL, to: destinationURL)
        XCTAssertEqual(result.destinationURL, destinationURL)
        XCTAssertEqual(result.extractedItemCount, 4)
        XCTAssertEqual(try String(contentsOf: destinationURL.appendingPathComponent("source/nested/b.txt")), "world")
    }

    func testSuggestedZIPDestinationUsesSingleSourceName() throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("report.txt")
        try Data("内容".utf8).write(to: sourceURL)

        let destination = try ArchiveService().suggestedZIPDestination(
            for: [sourceURL],
            in: temporaryDirectory
        )

        XCTAssertEqual(destination.lastPathComponent, "report.txt.zip")
    }

    func testSuggestedZIPDestinationUsesFirstSourceNameForMultipleSources() throws {
        let firstSource = temporaryDirectory.appendingPathComponent("top.txt")
        let secondSource = temporaryDirectory.appendingPathComponent("second.txt")
        try Data("1".utf8).write(to: firstSource)
        try Data("2".utf8).write(to: secondSource)

        let destination = try ArchiveService().suggestedZIPDestination(
            for: [firstSource, secondSource],
            in: temporaryDirectory
        )

        XCTAssertEqual(destination.lastPathComponent, "top.txt.zip")
    }

    func testSuggestedZIPDestinationAddsNumberWhenNameAlreadyExists() throws {
        let sourceURL = temporaryDirectory.appendingPathComponent("report.txt")
        try Data("内容".utf8).write(to: sourceURL)
        try Data().write(to: temporaryDirectory.appendingPathComponent("report.txt.zip"))
        try Data().write(to: temporaryDirectory.appendingPathComponent("report.txt_2.zip"))

        let destination = try ArchiveService().suggestedZIPDestination(
            for: [sourceURL],
            in: temporaryDirectory
        )

        XCTAssertEqual(destination.lastPathComponent, "report.txt_3.zip")
    }

    func testExtractRejectsPathTraversalBeforeWriting() throws {
        let archiveURL = temporaryDirectory.appendingPathComponent("unsafe.zip")
        let archive = try Archive(url: archiveURL, accessMode: .create)
        try archive.addEntry(
            with: "../outside.txt",
            type: .file,
            uncompressedSize: Int64(1),
            compressionMethod: .none,
            provider: { _, _ in Data("x".utf8) }
        )

        let destinationURL = temporaryDirectory.appendingPathComponent("expanded", isDirectory: true)
        XCTAssertThrowsError(try ArchiveService().extractZIP(at: archiveURL, to: destinationURL)) { error in
            XCTAssertEqual(error as? ArchiveServiceError, .invalidEntryPath("../outside.txt"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent("outside.txt").path))
    }

    func testCreateZIPRejectsSymbolicLinkSource() throws {
        let targetURL = temporaryDirectory.appendingPathComponent("target.txt")
        let linkURL = temporaryDirectory.appendingPathComponent("link.txt")
        try Data("target".utf8).write(to: targetURL)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        XCTAssertThrowsError(try ArchiveService().createZIP(
            from: [linkURL],
            to: temporaryDirectory.appendingPathComponent("output.zip")
        )) { error in
            XCTAssertEqual(error as? ArchiveServiceError, .symbolicLinkNotSupported(linkURL.path))
        }
    }

    func testEntriesAndExtractionDecodeShiftJISFileNames() throws {
        let archiveURL = temporaryDirectory.appendingPathComponent("legacy.zip")
        try makeStoredZIP(
            at: archiveURL,
            fileName: "日本語.txt",
            contents: Data("内容".utf8),
            fileNameEncoding: .shiftJIS
        )

        let service = ArchiveService()
        XCTAssertEqual(try service.entries(in: archiveURL).map(\.path), ["日本語.txt"])

        let destinationURL = temporaryDirectory.appendingPathComponent("expanded", isDirectory: true)
        _ = try service.extractZIP(at: archiveURL, to: destinationURL)
        XCTAssertEqual(
            try String(contentsOf: destinationURL.appendingPathComponent("日本語.txt"), encoding: .utf8),
            "内容"
        )
    }

    private func makeStoredZIP(
        at url: URL,
        fileName: String,
        contents: Data,
        fileNameEncoding: String.Encoding
    ) throws {
        guard let fileNameData = fileName.data(using: fileNameEncoding) else {
            XCTFail("ファイル名をエンコードできません")
            return
        }

        // テスト用の最小 ZIP。無圧縮・UTF-8 フラグなしで、旧来の日本語 ZIP を再現する。
        let crc: UInt32 = 0x3E7AA0AD
        var local = Data()
        local.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
        local.appendLE(UInt16(20))
        local.appendLE(UInt16(0))
        local.appendLE(UInt16(0))
        local.appendLE(UInt16(0))
        local.appendLE(UInt16(0))
        local.appendLE(crc)
        local.appendLE(UInt32(contents.count))
        local.appendLE(UInt32(contents.count))
        local.appendLE(UInt16(fileNameData.count))
        local.appendLE(UInt16(0))
        local.append(fileNameData)
        local.append(contents)

        var central = Data()
        central.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
        central.appendLE(UInt16(20))
        central.appendLE(UInt16(20))
        central.appendLE(UInt16(0))
        central.appendLE(UInt16(0))
        central.appendLE(UInt16(0))
        central.appendLE(UInt16(0))
        central.appendLE(crc)
        central.appendLE(UInt32(contents.count))
        central.appendLE(UInt32(contents.count))
        central.appendLE(UInt16(fileNameData.count))
        central.appendLE(UInt16(0))
        central.appendLE(UInt16(0))
        central.appendLE(UInt16(0))
        central.appendLE(UInt16(0))
        central.appendLE(UInt32(0))
        central.appendLE(UInt32(0))
        central.append(fileNameData)

        var end = Data()
        end.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(0))
        end.appendLE(UInt16(1))
        end.appendLE(UInt16(1))
        end.appendLE(UInt32(central.count))
        end.appendLE(UInt32(local.count))
        end.appendLE(UInt16(0))

        var archive = local
        archive.append(central)
        archive.append(end)
        try archive.write(to: url)
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
