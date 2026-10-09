@testable import MafxApp
import MafxCore
import XCTest

final class KeyBindingApplicationValidationTests: XCTestCase {
    func testAllowsApplyingKeyBindingsWithoutConflicts() {
        XCTAssertTrue(canApplyKeyBindingSet(.default))
    }

    func testPreventsApplyingDuplicateKeyBindings() {
        let keyBindingSet = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init(.init(key: "C"))]),
            KeyBindingEntry(commandID: .moveMarkedItems, sequences: [.init(.init(key: "C"))])
        ])

        XCTAssertFalse(canApplyKeyBindingSet(keyBindingSet))
    }

    func testPreventsApplyingPrefixConflicts() {
        let keyBindingSet = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init(.init(key: "S"))]),
            KeyBindingEntry(commandID: .sortByName, sequences: [.init([.init(key: "S"), .init(key: "F")])])
        ])

        XCTAssertFalse(canApplyKeyBindingSet(keyBindingSet))
    }

    func testPreventsApplyingPrefixConflictWithinOneCommand() {
        let keyBindingSet = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [
                .init(.init(key: "S")),
                .init([.init(key: "S"), .init(key: "F")])
            ])
        ])

        XCTAssertFalse(canApplyKeyBindingSet(keyBindingSet))
    }
}
