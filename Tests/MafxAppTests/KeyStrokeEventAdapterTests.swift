@testable import MafxApp
import AppKit
import MafxCore
import XCTest

final class KeyStrokeEventAdapterTests: XCTestCase {
    func testFunctionKeysUseStableDisplayNames() {
        let keyCodes: [(UInt16, String)] = [
            (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"),
            (96, "F5"), (97, "F6"), (98, "F7"), (100, "F8"),
            (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12")
        ]

        for (keyCode, expectedKey) in keyCodes {
            let event = makeKeyEvent(keyCode: keyCode)

            XCTAssertEqual(KeyStroke(event: event), KeyStroke(key: expectedKey))
        }
    }

    func testFunctionKeyPreservesModifiers() {
        let event = makeKeyEvent(keyCode: 122, modifierFlags: [.control, .option])

        XCTAssertEqual(
            KeyStroke(event: event),
            KeyStroke(key: "F1", modifiers: [.control, .option])
        )
    }

    private func makeKeyEvent(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}
