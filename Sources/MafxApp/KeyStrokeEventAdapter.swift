import AppKit
import MafxCore

enum IncrementalSearchInput {
    static func text(from event: NSEvent) -> String? {
        let commandModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(commandModifiers).isEmpty,
              let characters = event.characters,
              characters.count == 1,
              let scalar = characters.unicodeScalars.first,
              scalar.value < 128,
              scalar != " ",
              scalar != "\t",
              CharacterSet.alphanumerics.contains(scalar)
                || CharacterSet.punctuationCharacters.contains(scalar)
                || CharacterSet.symbols.contains(scalar) else {
            return nil
        }

        return characters
    }
}

extension KeyStroke {
    init?(event: NSEvent) {
        guard let key = Self.keyName(from: event) else {
            return nil
        }

        var modifiers: KeyModifiers = []
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }

        self.init(key: key, modifiers: modifiers)
    }

    private static func keyName(from event: NSEvent) -> String? {
        switch event.keyCode {
        case AppKeyCode.tab:
            return "Tab"
        case AppKeyCode.returnKey, AppKeyCode.keypadEnter:
            return "Return"
        case AppKeyCode.backspace:
            return "Backspace"
        case AppKeyCode.escape:
            return "Escape"
        case AppKeyCode.space:
            return "Space"
        case AppKeyCode.leftArrow:
            return "Left"
        case AppKeyCode.rightArrow:
            return "Right"
        case AppKeyCode.upArrow:
            return "Up"
        case AppKeyCode.downArrow:
            return "Down"
        case AppKeyCode.pageUp:
            return "PageUp"
        case AppKeyCode.pageDown:
            return "PageDown"
        case AppKeyCode.end:
            return "End"
        case AppKeyCode.f1:
            return "F1"
        case AppKeyCode.f2:
            return "F2"
        case AppKeyCode.f3:
            return "F3"
        case AppKeyCode.f4:
            return "F4"
        case AppKeyCode.f5:
            return "F5"
        case AppKeyCode.f6:
            return "F6"
        case AppKeyCode.f7:
            return "F7"
        case AppKeyCode.f8:
            return "F8"
        case AppKeyCode.f9:
            return "F9"
        case AppKeyCode.f10:
            return "F10"
        case AppKeyCode.f11:
            return "F11"
        case AppKeyCode.f12:
            return "F12"
        default:
            break
        }

        if let characters = event.characters, characters == "?" || characters == ":" || characters == "@" || characters == "_" || characters == "+" {
            return characters
        }

        guard let rawKey = event.charactersIgnoringModifiers, !rawKey.isEmpty else {
            return nil
        }

        if rawKey.count == 1, let scalar = rawKey.unicodeScalars.first {
            if CharacterSet.letters.contains(scalar) {
                return rawKey.uppercased()
            }
            return rawKey
        }

        return nil
    }
}

enum AppKeyCode {
    static let tab: UInt16 = 48
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let backspace: UInt16 = 51
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125
    static let pageUp: UInt16 = 116
    static let pageDown: UInt16 = 121
    static let end: UInt16 = 119
    static let f1: UInt16 = 122
    static let f2: UInt16 = 120
    static let f3: UInt16 = 99
    static let f4: UInt16 = 118
    static let f5: UInt16 = 96
    static let f6: UInt16 = 97
    static let f7: UInt16 = 98
    static let f8: UInt16 = 100
    static let f9: UInt16 = 101
    static let f10: UInt16 = 109
    static let f11: UInt16 = 103
    static let f12: UInt16 = 111
}
