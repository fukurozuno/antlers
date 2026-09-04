import Foundation
import XCTest
@testable import MafxCore

final class FileOperationServiceTests: XCTestCase {
    func testCreateDirectoryCreatesSingleFolderInParentDirectory() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let service = FileOperationService()
        let createdDirectory = try service.createDirectory(named: "New Folder", in: temporaryDirectory)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: createdDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(createdDirectory.deletingLastPathComponent(), temporaryDirectory)
    }

    func testCreateDirectoryRejectsEmptyName() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let service = FileOperationService()

        XCTAssertThrowsError(try service.createDirectory(named: "  ", in: temporaryDirectory)) { error in
            XCTAssertEqual(error as? FileOperationError, .emptyName)
        }
    }

    func testCreateDirectoryRejectsNestedPathName() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let service = FileOperationService()

        XCTAssertThrowsError(try service.createDirectory(named: "Parent/Child", in: temporaryDirectory)) { error in
            XCTAssertEqual(error as? FileOperationError, .invalidName("Parent/Child"))
        }
    }

    func testCreateDirectoryRejectsExistingDestination() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let existingDirectory = temporaryDirectory.appendingPathComponent("Existing", isDirectory: true)
        try FileManager.default.createDirectory(at: existingDirectory, withIntermediateDirectories: false)

        let service = FileOperationService()

        XCTAssertThrowsError(try service.createDirectory(named: "Existing", in: temporaryDirectory)) { error in
            XCTAssertEqual(error as? FileOperationError, .destinationAlreadyExists(existingDirectory))
        }
    }

    func testRenameItemRenamesFileInSameDirectory() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceFile = temporaryDirectory.appendingPathComponent("old.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let renamedFile = try service.renameItem(at: sourceFile, to: "new.txt", replacingExisting: false)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(renamedFile, temporaryDirectory.appendingPathComponent("new.txt"))
        XCTAssertEqual(try String(contentsOf: renamedFile, encoding: .utf8), "source")
    }

    func testRenameItemRejectsEmptyName() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceFile = temporaryDirectory.appendingPathComponent("old.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()

        XCTAssertThrowsError(try service.renameItem(at: sourceFile, to: "  ", replacingExisting: false)) { error in
            XCTAssertEqual(error as? FileOperationError, .emptyName)
        }
    }

    func testRenameItemRejectsExistingDestinationWithoutReplace() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceFile = temporaryDirectory.appendingPathComponent("old.txt")
        let destinationFile = temporaryDirectory.appendingPathComponent("existing.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "destination".write(to: destinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()

        XCTAssertThrowsError(try service.renameItem(at: sourceFile, to: "existing.txt", replacingExisting: false)) { error in
            XCTAssertEqual(error as? FileOperationError, .destinationAlreadyExists(destinationFile))
        }
        XCTAssertEqual(try String(contentsOf: sourceFile, encoding: .utf8), "source")
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "destination")
    }

    func testRenameItemReplacesExistingDestinationWhenExplicitlyAllowed() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceFile = temporaryDirectory.appendingPathComponent("old.txt")
        let destinationFile = temporaryDirectory.appendingPathComponent("existing.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "destination".write(to: destinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let renamedFile = try service.renameItem(at: sourceFile, to: "existing.txt", replacingExisting: true)

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(renamedFile, destinationFile)
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "source")
    }

    func testCopyItemCopiesFileWithNewNameInSameDirectory() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceFile = temporaryDirectory.appendingPathComponent("old.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let copiedFile = try service.copyItem(at: sourceFile, to: "new.txt", replacingExisting: false)

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(copiedFile, temporaryDirectory.appendingPathComponent("new.txt"))
        XCTAssertEqual(try String(contentsOf: copiedFile, encoding: .utf8), "source")
    }

    func testCopyItemRejectsExistingDestinationWithoutReplace() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceFile = temporaryDirectory.appendingPathComponent("old.txt")
        let destinationFile = temporaryDirectory.appendingPathComponent("existing.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "destination".write(to: destinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()

        XCTAssertThrowsError(try service.copyItem(at: sourceFile, to: "existing.txt", replacingExisting: false)) { error in
            XCTAssertEqual(error as? FileOperationError, .destinationAlreadyExists(destinationFile))
        }
        XCTAssertEqual(try String(contentsOf: sourceFile, encoding: .utf8), "source")
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "destination")
    }

    func testCopyItemReplacesExistingDestinationWhenExplicitlyAllowed() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceFile = temporaryDirectory.appendingPathComponent("old.txt")
        let destinationFile = temporaryDirectory.appendingPathComponent("existing.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "destination".write(to: destinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let copiedFile = try service.copyItem(at: sourceFile, to: "existing.txt", replacingExisting: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(copiedFile, destinationFile)
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "source")
    }

    func testCopyItemsCopiesFileToDestinationDirectory() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.copyItems(at: [sourceFile], to: destinationDirectory) { _ in .skip }

        let copiedFile = destinationDirectory.appendingPathComponent("file.txt")
        XCTAssertCopyResult(result, copiedCount: 1, skippedCount: 0)
        XCTAssertEqual(result.itemResults, [
            FileOperationItemResult(sourceURL: sourceFile, destinationURL: copiedFile, outcome: .copied)
        ])
        XCTAssertEqual(try String(contentsOf: copiedFile, encoding: .utf8), "source")
    }

    func testCopyItemsCopiesDirectoryRecursively() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("folder", isDirectory: true)
        let nestedDirectory = sourceDirectory.appendingPathComponent("nested", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let nestedFile = nestedDirectory.appendingPathComponent("file.txt")
        try "nested".write(to: nestedFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.copyItems(at: [sourceDirectory], to: destinationDirectory) { _ in .skip }

        let copiedFile = destinationDirectory
            .appendingPathComponent("folder", isDirectory: true)
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("file.txt")
        XCTAssertCopyResult(result, copiedCount: 1, skippedCount: 0)
        XCTAssertEqual(try String(contentsOf: copiedFile, encoding: .utf8), "nested")
    }

    func testCopyItemsSkipsExistingDestinationWhenConflictResolutionIsSkip() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        let destinationFile = destinationDirectory.appendingPathComponent("file.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "destination".write(to: destinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.copyItems(at: [sourceFile], to: destinationDirectory) { _ in .skip }

        XCTAssertCopyResult(result, copiedCount: 0, skippedCount: 1)
        XCTAssertEqual(result.itemResults, [
            FileOperationItemResult(sourceURL: sourceFile, destinationURL: destinationFile, outcome: .skipped(reason: .conflict))
        ])
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "destination")
    }

    func testCopyItemsStopsAtConflictWhenConflictResolutionIsCancel() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)

        let firstSource = sourceDirectory.appendingPathComponent("first.txt")
        let conflictingSource = sourceDirectory.appendingPathComponent("conflict.txt")
        let remainingSource = sourceDirectory.appendingPathComponent("remaining.txt")
        let conflictingDestination = destinationDirectory.appendingPathComponent("conflict.txt")
        try "first".write(to: firstSource, atomically: true, encoding: .utf8)
        try "source".write(to: conflictingSource, atomically: true, encoding: .utf8)
        try "remaining".write(to: remainingSource, atomically: true, encoding: .utf8)
        try "destination".write(to: conflictingDestination, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.copyItems(at: [firstSource, conflictingSource, remainingSource], to: destinationDirectory) { _ in .cancel }

        XCTAssertCopyResult(result, copiedCount: 1, skippedCount: 0, unprocessedCount: 2, wasCancelled: true)
        XCTAssertEqual(result.itemResults.map(\.outcome), [.copied, .unprocessed, .unprocessed])
        XCTAssertEqual(try String(contentsOf: destinationDirectory.appendingPathComponent("first.txt"), encoding: .utf8), "first")
        XCTAssertEqual(try String(contentsOf: conflictingDestination, encoding: .utf8), "destination")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationDirectory.appendingPathComponent("remaining.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstSource.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: conflictingSource.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: remainingSource.path))
    }

    func testCopyItemsReplacesExistingDestinationWhenConflictResolutionIsCopy() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        let destinationFile = destinationDirectory.appendingPathComponent("file.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "destination".write(to: destinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.copyItems(at: [sourceFile], to: destinationDirectory) { _ in .copy }

        XCTAssertCopyResult(result, copiedCount: 1, skippedCount: 0)
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "source")
    }

    func testCopyItemsCopiesExistingDestinationOnlyWhenSourceIsNewer() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        let destinationFile = destinationDirectory.appendingPathComponent("file.txt")
        try "new".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "old".write(to: destinationFile, atomically: true, encoding: .utf8)
        try setModificationDate(Date(timeIntervalSince1970: 200), for: sourceFile)
        try setModificationDate(Date(timeIntervalSince1970: 100), for: destinationFile)

        let service = FileOperationService()
        let result = try service.copyItems(at: [sourceFile], to: destinationDirectory) { _ in
            .copyIfSourceIsNewer
        }

        XCTAssertCopyResult(result, copiedCount: 1, skippedCount: 0)
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "new")
    }

    func testCopyItemsSkipsExistingDestinationWhenSourceIsNotNewer() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        let destinationFile = destinationDirectory.appendingPathComponent("file.txt")
        try "old".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "new".write(to: destinationFile, atomically: true, encoding: .utf8)
        try setModificationDate(Date(timeIntervalSince1970: 100), for: sourceFile)
        try setModificationDate(Date(timeIntervalSince1970: 200), for: destinationFile)

        let service = FileOperationService()
        let result = try service.copyItems(at: [sourceFile], to: destinationDirectory) { _ in
            .copyIfSourceIsNewer
        }

        XCTAssertCopyResult(result, copiedCount: 0, skippedCount: 1)
        XCTAssertEqual(result.itemResults, [
            FileOperationItemResult(sourceURL: sourceFile, destinationURL: destinationFile, outcome: .skipped(reason: .sourceIsNotNewer))
        ])
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "new")
    }

    func testCopyItemsRejectsCopyingDirectoryIntoItself() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let childDirectory = sourceDirectory.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: childDirectory, withIntermediateDirectories: true)

        let service = FileOperationService()

        XCTAssertThrowsError(try service.copyItems(at: [sourceDirectory], to: childDirectory) { _ in .copy }) { error in
            XCTAssertEqual(
                error as? FileOperationError,
                .destinationInsideSource(
                    source: sourceDirectory,
                    destination: childDirectory.appendingPathComponent("source")
                )
            )
        }
    }

    func testMoveItemsMovesFileToDestinationDirectory() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.moveItems(at: [sourceFile], to: destinationDirectory) { _ in .skip }

        let movedFile = destinationDirectory.appendingPathComponent("file.txt")
        XCTAssertMoveResult(result, movedCount: 1, skippedCount: 0)
        XCTAssertEqual(result.itemResults, [
            FileOperationItemResult(sourceURL: sourceFile, destinationURL: movedFile, outcome: .moved)
        ])
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(try String(contentsOf: movedFile, encoding: .utf8), "source")
    }

    func testMoveItemsMovesDirectoryRecursively() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("folder", isDirectory: true)
        let nestedDirectory = sourceDirectory.appendingPathComponent("nested", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let nestedFile = nestedDirectory.appendingPathComponent("file.txt")
        try "nested".write(to: nestedFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.moveItems(at: [sourceDirectory], to: destinationDirectory) { _ in .skip }

        let movedFile = destinationDirectory
            .appendingPathComponent("folder", isDirectory: true)
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("file.txt")
        XCTAssertMoveResult(result, movedCount: 1, skippedCount: 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceDirectory.path))
        XCTAssertEqual(try String(contentsOf: movedFile, encoding: .utf8), "nested")
    }

    func testMoveItemsSkipsExistingDestinationWhenConflictResolutionIsSkip() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        let destinationFile = destinationDirectory.appendingPathComponent("file.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "destination".write(to: destinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.moveItems(at: [sourceFile], to: destinationDirectory) { _ in .skip }

        XCTAssertMoveResult(result, movedCount: 0, skippedCount: 1)
        XCTAssertEqual(result.itemResults, [
            FileOperationItemResult(sourceURL: sourceFile, destinationURL: destinationFile, outcome: .skipped(reason: .conflict))
        ])
        XCTAssertEqual(try String(contentsOf: sourceFile, encoding: .utf8), "source")
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "destination")
    }

    func testMoveItemsStopsAtConflictWhenConflictResolutionIsCancel() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)

        let firstSource = sourceDirectory.appendingPathComponent("first.txt")
        let conflictingSource = sourceDirectory.appendingPathComponent("conflict.txt")
        let remainingSource = sourceDirectory.appendingPathComponent("remaining.txt")
        let conflictingDestination = destinationDirectory.appendingPathComponent("conflict.txt")
        try "first".write(to: firstSource, atomically: true, encoding: .utf8)
        try "source".write(to: conflictingSource, atomically: true, encoding: .utf8)
        try "remaining".write(to: remainingSource, atomically: true, encoding: .utf8)
        try "destination".write(to: conflictingDestination, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.moveItems(at: [firstSource, conflictingSource, remainingSource], to: destinationDirectory) { _ in .cancel }

        XCTAssertMoveResult(result, movedCount: 1, skippedCount: 0, unprocessedCount: 2, wasCancelled: true)
        XCTAssertEqual(result.itemResults.map(\.outcome), [.moved, .unprocessed, .unprocessed])
        XCTAssertEqual(try String(contentsOf: destinationDirectory.appendingPathComponent("first.txt"), encoding: .utf8), "first")
        XCTAssertEqual(try String(contentsOf: conflictingDestination, encoding: .utf8), "destination")
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationDirectory.appendingPathComponent("remaining.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstSource.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: conflictingSource.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: remainingSource.path))
    }

    func testMoveItemsReplacesExistingDestinationWhenConflictResolutionIsMove() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        let destinationFile = destinationDirectory.appendingPathComponent("file.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "destination".write(to: destinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.moveItems(at: [sourceFile], to: destinationDirectory) { _ in .move }

        XCTAssertMoveResult(result, movedCount: 1, skippedCount: 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "source")
    }

    func testMoveItemsReplacesExistingDirectoryWithoutMergingWhenConflictResolutionIsMove() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceRoot = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationRoot = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: false)

        let sourceDirectory = sourceRoot.appendingPathComponent("folder", isDirectory: true)
        let destinationDirectory = destinationRoot.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("source.txt")
        let staleDestinationFile = destinationDirectory.appendingPathComponent("stale.txt")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "stale".write(to: staleDestinationFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.moveItems(at: [sourceDirectory], to: destinationRoot) { _ in .move }

        let movedSourceFile = destinationDirectory.appendingPathComponent("source.txt")
        XCTAssertMoveResult(result, movedCount: 1, skippedCount: 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceDirectory.path))
        XCTAssertEqual(try String(contentsOf: movedSourceFile, encoding: .utf8), "source")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleDestinationFile.path))
    }

    func testMoveItemsMovesExistingDestinationOnlyWhenSourceIsNewer() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        let destinationFile = destinationDirectory.appendingPathComponent("file.txt")
        try "new".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "old".write(to: destinationFile, atomically: true, encoding: .utf8)
        try setModificationDate(Date(timeIntervalSince1970: 200), for: sourceFile)
        try setModificationDate(Date(timeIntervalSince1970: 100), for: destinationFile)

        let service = FileOperationService()
        let result = try service.moveItems(at: [sourceFile], to: destinationDirectory) { _ in
            .moveIfSourceIsNewer
        }

        XCTAssertMoveResult(result, movedCount: 1, skippedCount: 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "new")
    }

    func testMoveItemsSkipsExistingDestinationWhenSourceIsNotNewer() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceDirectory = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = temporaryDirectory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let sourceFile = sourceDirectory.appendingPathComponent("file.txt")
        let destinationFile = destinationDirectory.appendingPathComponent("file.txt")
        try "old".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "new".write(to: destinationFile, atomically: true, encoding: .utf8)
        try setModificationDate(Date(timeIntervalSince1970: 100), for: sourceFile)
        try setModificationDate(Date(timeIntervalSince1970: 200), for: destinationFile)

        let service = FileOperationService()
        let result = try service.moveItems(at: [sourceFile], to: destinationDirectory) { _ in
            .moveIfSourceIsNewer
        }

        XCTAssertMoveResult(result, movedCount: 0, skippedCount: 1)
        XCTAssertEqual(result.itemResults, [
            FileOperationItemResult(sourceURL: sourceFile, destinationURL: destinationFile, outcome: .skipped(reason: .sourceIsNotNewer))
        ])
        XCTAssertEqual(try String(contentsOf: sourceFile, encoding: .utf8), "old")
        XCTAssertEqual(try String(contentsOf: destinationFile, encoding: .utf8), "new")
    }

    func testTrashItemsMovesFileToTrash() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let sourceFile = temporaryDirectory.appendingPathComponent("trashed.txt")
        try "trash".write(to: sourceFile, atomically: true, encoding: .utf8)

        let service = FileOperationService()
        let result = try service.trashItems(at: [sourceFile])

        XCTAssertEqual(result.trashedCount, 1)
        XCTAssertEqual(result.itemResults.map(\.outcome), [.trashed])
        XCTAssertEqual(result.itemResults.map(\.sourceURL), [sourceFile])
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
    }

    func testTrashItemsRejectsMissingSource() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let missingFile = temporaryDirectory.appendingPathComponent("missing.txt")

        let service = FileOperationService()

        XCTAssertThrowsError(try service.trashItems(at: [missingFile])) { error in
            XCTAssertEqual(error as? FileOperationError, .sourceDoesNotExist(missingFile))
        }
    }

    func testConfinedTrashDoesNotUseSystemTrash() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceFile = root.appendingPathComponent("file.txt")
        try Data("content".utf8).write(to: sourceFile)
        let scope = try XCTUnwrap(FileSystemScope(confinedRootURL: root))
        let service = FileOperationService(scope: scope)

        let result = try service.trashItems(at: [sourceFile])

        XCTAssertEqual(result.trashedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceFile.path))
        XCTAssertTrue(result.itemResults[0].destinationURL?.path.hasPrefix(root.appendingPathComponent(".antlers-trash").path) == true)
    }

    func testConfinedCopyPrevalidatesAllSourcesBeforeChangingDestination() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceDirectory = root.appendingPathComponent("source", isDirectory: true)
        let destinationDirectory = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: false)
        let inside = sourceDirectory.appendingPathComponent("inside.txt")
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside.txt")
        try Data().write(to: inside)
        try Data().write(to: outside)
        let scope = try XCTUnwrap(FileSystemScope(confinedRootURL: root))
        let service = FileOperationService(scope: scope)

        XCTAssertThrowsError(try service.copyItems(at: [inside, outside], to: destinationDirectory) { _ in .copy }) { error in
            XCTAssertEqual(error as? FileOperationError, .outsideScope(outside))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationDirectory.appendingPathComponent("inside.txt").path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func setModificationDate(_ date: Date, for url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    private func XCTAssertCopyResult(
        _ result: FileCopyResult,
        copiedCount: Int,
        skippedCount: Int,
        unprocessedCount: Int = 0,
        wasCancelled: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(result.copiedCount, copiedCount, file: file, line: line)
        XCTAssertEqual(result.skippedCount, skippedCount, file: file, line: line)
        XCTAssertEqual(result.unprocessedCount, unprocessedCount, file: file, line: line)
        XCTAssertEqual(result.wasCancelled, wasCancelled, file: file, line: line)
    }

    private func XCTAssertMoveResult(
        _ result: FileMoveResult,
        movedCount: Int,
        skippedCount: Int,
        unprocessedCount: Int = 0,
        wasCancelled: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(result.movedCount, movedCount, file: file, line: line)
        XCTAssertEqual(result.skippedCount, skippedCount, file: file, line: line)
        XCTAssertEqual(result.unprocessedCount, unprocessedCount, file: file, line: line)
        XCTAssertEqual(result.wasCancelled, wasCancelled, file: file, line: line)
    }
}
