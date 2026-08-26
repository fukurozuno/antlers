import XCTest
@testable import MafxCore

final class FilePatternHistoryTests: XCTestCase {
    func testRecordMovesExistingPatternToFrontAndIgnoresEmptyValues() {
        var history = FilePatternHistory(entries: ["*.swift", "*.md"])

        history.record("*.md")
        history.record("  ")

        XCTAssertEqual(history.entries, ["*.md", "*.swift"])
    }

    func testInitialValuesAreTrimmedDeduplicatedAndLimited() {
        let entries = (0...FilePatternHistory.maximumEntryCount).map { "pattern-\($0)" }
        let history = FilePatternHistory(entries: ["  *.swift  ", "*.swift"] + entries)

        XCTAssertEqual(history.entries.first, "*.swift")
        XCTAssertEqual(history.entries.count, FilePatternHistory.maximumEntryCount)
    }
}
