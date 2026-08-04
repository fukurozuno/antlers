@testable import MafxApp
import MafxCore
import XCTest

final class SettingsListEditorValidationTests: XCTestCase {
    func testDetectsUpdatedBookmarkThatHasNotBeenApplied() {
        XCTAssertTrue(hasUnappliedSettingsListEditorChanges(
            current: .bookmark(displayName: "Work", path: "/tmp/updated"),
            applied: .bookmark(displayName: "Work", path: "/tmp/original")
        ))
    }

    func testAllowsBookmarkEditorMatchingAppliedEntry() {
        XCTAssertFalse(hasUnappliedSettingsListEditorChanges(
            current: .bookmark(displayName: "Work", path: "/tmp/work"),
            applied: .bookmark(displayName: "Work", path: "/tmp/work")
        ))
    }

    func testDetectsUpdatedFileTypeThatHasNotBeenApplied() {
        XCTAssertTrue(hasUnappliedSettingsListEditorChanges(
            current: .fileType(extensions: "txt,md", isOtherExtensions: false, applicationPath: "/Applications/Editor.app", color: nil),
            applied: .fileType(extensions: "txt", isOtherExtensions: false, applicationPath: "/Applications/Editor.app", color: nil)
        ))
    }

    func testDetectsNewBookmarkThatHasNotBeenAdded() {
        XCTAssertTrue(hasUnappliedSettingsListEditorChanges(
            current: .bookmark(displayName: "Work", path: "/tmp/work"),
            applied: .bookmark(displayName: "", path: "")
        ))
    }

    func testIgnoresEditorOutsideListTabs() {
        XCTAssertFalse(hasUnappliedSettingsListEditorChanges(current: nil, applied: nil))
    }
}
