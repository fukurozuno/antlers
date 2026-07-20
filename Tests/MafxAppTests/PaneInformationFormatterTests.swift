@testable import MafxApp
import MafxCore
import XCTest

final class PaneInformationFormatterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let resourceDirectory = projectDirectory.appendingPathComponent("Sources/MafxApp/Resources", isDirectory: true)
        L10n.setResourceDirectoryForTesting(resourceDirectory)
    }

    override func tearDown() {
        L10n.setAppLanguage(.system)
        L10n.setResourceDirectoryForTesting(nil)
        super.tearDown()
    }

    func testDevelopmentBuildLoadsLocalizationResourcesFromProjectDirectory() {
        L10n.setResourceDirectoryForTesting(nil)
        L10n.setAppLanguage(.japanese)

        XCTAssertEqual(L10n.string("settings.language.japanese"), "日本語")
    }

    func testJapaneseFormatSeparatesMarkedDirectoryCountFromFileTotalSize() {
        L10n.setAppLanguage(.japanese)
        let directory = URL(fileURLWithPath: "/tmp/pane-information")
        let firstFile = FileItem(
            url: directory.appendingPathComponent("first.txt"),
            isDirectory: false,
            byteSize: 1_000
        )
        let secondFile = FileItem(
            url: directory.appendingPathComponent("second.txt"),
            isDirectory: false,
            byteSize: 24
        )
        let markedDirectory = FileItem(
            url: directory.appendingPathComponent("folder"),
            isDirectory: true,
            byteSize: 9_999
        )
        let state = PaneState(
            currentDirectory: directory,
            items: [firstFile, secondFile, markedDirectory],
            markedItemURLs: [firstFile.url, secondFile.url, markedDirectory.url]
        )

        XCTAssertEqual(
            PaneInformationFormatter().string(for: state),
            "3 件選択 ( 1 KB、フォルダ 1 件 )"
        )
    }

    func testJapaneseFormatDoesNotDisplayZeroBytesForOnlyMarkedDirectories() {
        L10n.setAppLanguage(.japanese)
        let directory = URL(fileURLWithPath: "/tmp/pane-information")
        let firstDirectory = FileItem(
            url: directory.appendingPathComponent("first"),
            isDirectory: true
        )
        let secondDirectory = FileItem(
            url: directory.appendingPathComponent("second"),
            isDirectory: true
        )
        let state = PaneState(
            currentDirectory: directory,
            items: [firstDirectory, secondDirectory],
            markedItemURLs: [firstDirectory.url, secondDirectory.url]
        )

        XCTAssertEqual(PaneInformationFormatter().string(for: state), "2 件選択 ( フォルダ 2 件 )")
    }

    func testJapaneseFormatIdentifiesFilesWhoseSizeIsUnavailable() {
        L10n.setAppLanguage(.japanese)
        let directory = URL(fileURLWithPath: "/tmp/pane-information")
        let knownSizeFile = FileItem(
            url: directory.appendingPathComponent("known.txt"),
            isDirectory: false,
            byteSize: 24
        )
        let unknownSizeFile = FileItem(
            url: directory.appendingPathComponent("unknown.txt"),
            isDirectory: false
        )
        let state = PaneState(
            currentDirectory: directory,
            items: [knownSizeFile, unknownSizeFile],
            markedItemURLs: [knownSizeFile.url, unknownSizeFile.url]
        )

        XCTAssertEqual(PaneInformationFormatter().string(for: state), "2 件選択 ( 24  B、サイズ不明 1 件 )")
    }

    func testConfigurationCanHideAllInformationFields() {
        let state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp/pane-information"))
        let configuration = PaneInformationDisplayConfiguration(fields: [])

        XCTAssertEqual(PaneInformationFormatter(configuration: configuration).string(for: state), "")
    }
}
