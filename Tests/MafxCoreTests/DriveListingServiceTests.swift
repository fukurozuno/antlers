import Foundation
import XCTest
@testable import MafxCore

final class DriveListingServiceTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        let fileManager = FileManager.default
        for directory in temporaryDirectories {
            try? fileManager.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()

        try super.tearDownWithError()
    }

    func testLocationsIncludeMountedVolumesICloudDriveAndCloudStorage() throws {
        let fileManager = FileManager.default
        let homeDirectory = try makeTemporaryDirectory()
        let volumesDirectory = try makeDirectory(
            at: homeDirectory.appendingPathComponent("Volumes", isDirectory: true)
        )
        let mountedVolume = try makeDirectory(
            at: volumesDirectory
                .appendingPathComponent("NetworkShare", isDirectory: true)
        )
        let fallbackNetworkVolume = try makeDirectory(
            at: volumesDirectory
                .appendingPathComponent("MountedOnlyInVolumes", isDirectory: true)
        )
        let iCloudDrive = try makeDirectory(
            at: homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Mobile Documents", isDirectory: true)
                .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)
        )
        let oneDrive = try makeDirectory(
            at: homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("CloudStorage", isDirectory: true)
                .appendingPathComponent("OneDrive", isDirectory: true)
        )
        _ = try makeDirectory(
            at: homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("CloudStorage", isDirectory: true)
                .appendingPathComponent(".HiddenProvider", isDirectory: true)
        )

        let service = DriveListingService(
            fileManager: fileManager,
            homeDirectory: homeDirectory,
            volumesDirectory: volumesDirectory,
            mountedVolumeURLsProvider: { [mountedVolume, iCloudDrive] in
                [mountedVolume, iCloudDrive]
            }
        )

        let volumes = try service.locations()

        XCTAssertFalse(volumes.isEmpty)
        XCTAssertTrue(volumes.allSatisfy { $0.url.isFileURL })
        XCTAssertTrue(volumes.allSatisfy { !$0.displayName.isEmpty })
        XCTAssertTrue(volumes.contains { hasPath($0.url, equalTo: mountedVolume) })
        XCTAssertTrue(volumes.contains { hasPath($0.url, equalTo: fallbackNetworkVolume) })
        XCTAssertTrue(volumes.contains { hasPath($0.url, equalTo: iCloudDrive) && $0.displayName == "iCloud Drive" })
        XCTAssertTrue(volumes.contains { hasPath($0.url, equalTo: oneDrive) && $0.displayName == "OneDrive" })
        XCTAssertEqual(volumes.filter { hasPath($0.url, equalTo: iCloudDrive) }.count, 1)
        XCTAssertFalse(volumes.contains { $0.displayName == ".HiddenProvider" })
        XCTAssertEqual(
            volumes.map(\.displayName),
            volumes.map(\.displayName).sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }

    @discardableResult
    private func makeDirectory(at url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func hasPath(_ lhs: URL, equalTo rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }
}
