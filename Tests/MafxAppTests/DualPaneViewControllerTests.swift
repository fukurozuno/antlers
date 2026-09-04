@testable import MafxApp
import AppKit
import MafxCore
import XCTest

final class DualPaneViewControllerTests: XCTestCase {
    private var temporaryDirectoryURL: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "DualPaneViewControllerTests-\(UUID().uuidString)",
            isDirectory: true
        ).resolvingSymlinksInPath()
        try? FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
        super.tearDown()
    }

    private func createTestZipArchive() throws -> URL {
        let sampleFileURL = temporaryDirectoryURL.appendingPathComponent("sample.txt")
        try "hello".write(to: sampleFileURL, atomically: true, encoding: .utf8)
        let zipURL = temporaryDirectoryURL.appendingPathComponent("archive.zip")
        let archiveService = ArchiveService()
        try archiveService.createZIP(from: [sampleFileURL], to: zipURL)
        return zipURL
    }

    private func selectZipInActivePane(on viewController: DualPaneViewController, zipName: String) {
        viewController.mutateActivePane { paneState in
            paneState.loadCurrentDirectory(using: DirectoryListingService())
            if let index = paneState.items.firstIndex(where: { $0.name == zipName }) {
                paneState.selectItem(at: index)
            }
        }
    }

    func testReturnKeyBrowsesZipWhenTreatZipAsDirectoryOnAndOpenSelectedDirectory() throws {
        let zipURL = try createTestZipArchive()
        let settings = AppSettings(
            treatZipAsDirectory: true,
            returnKeyBehavior: .openSelectedDirectory,
            leftPanePath: temporaryDirectoryURL.path,
            rightPanePath: temporaryDirectoryURL.path
        )
        let viewController = DualPaneViewController(settings: settings)
        selectZipInActivePane(on: viewController, zipName: zipURL.lastPathComponent)

        XCTAssertEqual(viewController.activePaneState.selectedItem?.name, zipURL.lastPathComponent)

        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!

        viewController.keyDown(with: event)

        XCTAssertTrue(viewController.activePaneState.isBrowsingArchive)
    }

    func testReturnKeyBrowsesZipWhenTreatZipAsDirectoryOnAndPreviewFileOrOpenDirectory() throws {
        let zipURL = try createTestZipArchive()
        let settings = AppSettings(
            treatZipAsDirectory: true,
            returnKeyBehavior: .previewFileOrOpenDirectory,
            leftPanePath: temporaryDirectoryURL.path,
            rightPanePath: temporaryDirectoryURL.path
        )
        let viewController = DualPaneViewController(settings: settings)
        selectZipInActivePane(on: viewController, zipName: zipURL.lastPathComponent)

        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!

        viewController.keyDown(with: event)

        XCTAssertTrue(viewController.activePaneState.isBrowsingArchive)
    }

    func testReturnKeyDoesNotBrowseZipWhenReturnKeyBehaviorIsDisabled() throws {
        let zipURL = try createTestZipArchive()
        let settings = AppSettings(
            treatZipAsDirectory: true,
            returnKeyBehavior: .disabled,
            leftPanePath: temporaryDirectoryURL.path,
            rightPanePath: temporaryDirectoryURL.path
        )
        let viewController = DualPaneViewController(settings: settings)
        selectZipInActivePane(on: viewController, zipName: zipURL.lastPathComponent)

        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!

        viewController.keyDown(with: event)

        XCTAssertFalse(viewController.activePaneState.isBrowsingArchive)
    }

    func testReturnKeyDoesNotBrowseZipWhenTreatZipAsDirectoryIsOff() throws {
        let zipURL = try createTestZipArchive()
        let settings = AppSettings(
            treatZipAsDirectory: false,
            returnKeyBehavior: .openSelectedDirectory,
            leftPanePath: temporaryDirectoryURL.path,
            rightPanePath: temporaryDirectoryURL.path
        )
        let viewController = DualPaneViewController(settings: settings)
        selectZipInActivePane(on: viewController, zipName: zipURL.lastPathComponent)

        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!

        viewController.keyDown(with: event)

        XCTAssertFalse(viewController.activePaneState.isBrowsingArchive)
    }
}
