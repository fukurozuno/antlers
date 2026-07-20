import Foundation
import XCTest
@testable import MafxCore

final class NavigationHistoryTests: XCTestCase {
    func testPreparedRecordsCurrentDirectoryWhenHistoryIsEmpty() {
        let history = NavigationHistory().prepared(for: URL(fileURLWithPath: "/tmp/root"))

        XCTAssertEqual(history.paths, ["/tmp/root"])
        XCTAssertEqual(history.currentIndex, 0)
    }

    func testRecordTruncatesForwardHistory() {
        var history = NavigationHistory(paths: ["/tmp/a", "/tmp/b", "/tmp/c"], currentIndex: 2)

        XCTAssertEqual(history.moveBackward()?.path, "/tmp/b")
        history.record(URL(fileURLWithPath: "/tmp/d"))

        XCTAssertEqual(history.paths, ["/tmp/a", "/tmp/b", "/tmp/d"])
        XCTAssertEqual(history.currentIndex, 2)
    }

    func testRecordKeepsHistoryBackAndForwardAsIndexOnlyOperations() {
        var history = NavigationHistory(paths: ["/tmp/a", "/tmp/b", "/tmp/c"], currentIndex: 2)

        XCTAssertEqual(history.moveBackward()?.path, "/tmp/b")
        XCTAssertEqual(history.paths, ["/tmp/a", "/tmp/b", "/tmp/c"])
        XCTAssertEqual(history.currentIndex, 1)

        XCTAssertEqual(history.moveForward()?.path, "/tmp/c")
        XCTAssertEqual(history.paths, ["/tmp/a", "/tmp/b", "/tmp/c"])
        XCTAssertEqual(history.currentIndex, 2)
    }

    func testMoveBackwardAndForwardUpdateCurrentIndex() {
        var history = NavigationHistory(paths: ["/tmp/a", "/tmp/b"], currentIndex: 1)

        XCTAssertEqual(history.moveBackward()?.path, "/tmp/a")
        XCTAssertEqual(history.currentIndex, 0)
        XCTAssertNil(history.moveBackward())

        XCTAssertEqual(history.moveForward()?.path, "/tmp/b")
        XCTAssertEqual(history.currentIndex, 1)
        XCTAssertNil(history.moveForward())
    }

    func testMoveToPathUpdatesCurrentIndex() {
        var history = NavigationHistory(paths: ["/tmp/a", "/tmp/b", "/tmp/c"], currentIndex: 0)

        XCTAssertEqual(history.moveToPath(at: 2)?.path, "/tmp/c")

        XCTAssertEqual(history.currentIndex, 2)
    }
}
