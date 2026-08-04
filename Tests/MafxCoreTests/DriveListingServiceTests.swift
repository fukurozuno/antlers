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
            },
            mountedVolumeMetadataProvider: { url in
                MountedVolumeMetadata(
                    localizedName: url.lastPathComponent,
                    isInternal: url != mountedVolume,
                    isLocal: true,
                    isRootFileSystem: false
                )
            }
        )

        let volumes = try service.locations()

        XCTAssertFalse(volumes.isEmpty)
        XCTAssertTrue(volumes.allSatisfy { $0.url.isFileURL })
        XCTAssertTrue(volumes.allSatisfy { !$0.displayName.isEmpty })
        XCTAssertTrue(volumes.contains { hasPath($0.url, equalTo: mountedVolume) })
        XCTAssertTrue(volumes.first { hasPath($0.url, equalTo: mountedVolume) }?.isUnmountable == true)
        XCTAssertTrue(volumes.first { hasPath($0.url, equalTo: iCloudDrive) }?.isUnmountable == false)
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

    func testMountedVolumeMetadataAllowsOnlyExternalLocalNonRootVolumes() {
        XCTAssertTrue(
            MountedVolumeMetadata(
                localizedName: "External",
                isInternal: false,
                isLocal: true,
                isRootFileSystem: false
            ).isUnmountable
        )
        XCTAssertFalse(
            MountedVolumeMetadata(
                localizedName: "Internal",
                isInternal: true,
                isLocal: true,
                isRootFileSystem: false
            ).isUnmountable
        )
        XCTAssertFalse(
            MountedVolumeMetadata(
                localizedName: "Network",
                isInternal: false,
                isLocal: false,
                isRootFileSystem: false
            ).isUnmountable
        )
        XCTAssertFalse(
            MountedVolumeMetadata(
                localizedName: "Root",
                isInternal: false,
                isLocal: true,
                isRootFileSystem: true
            ).isUnmountable
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
