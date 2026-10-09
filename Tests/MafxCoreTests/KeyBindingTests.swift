import XCTest
@testable import MafxCore

final class KeyBindingTests: XCTestCase {
    func testDefaultFontSizeCommandsUseCommandPlusMinusAndZero() {
        let resolver = KeymapResolver(keyBindingSet: .default)

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "+", modifiers: [.shift, .command])),
            .matched(.increaseFileListFontSize)
        )
        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "-", modifiers: .command)),
            .matched(.decreaseFileListFontSize)
        )
        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "0", modifiers: .command)),
            .matched(.resetFileListFontSize)
        )
    }

    func testDefaultControlReturnOpensWithConfiguredApplication() {
        let resolver = KeymapResolver(keyBindingSet: .default)

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "Return", modifiers: .control)),
            .matched(.openWithConfiguredApplication)
        )
    }

    func testDefaultContextMenuShortcutUsesSlash() {
        let resolver = KeymapResolver(keyBindingSet: .default)

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "/")), .matched(.showContextMenu))
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .showContextMenu), [.init(.init(key: "/"))])
    }

    func testDefaultCommandPaletteShortcutsDoNotConflict() {
        let resolver = KeymapResolver(keyBindingSet: .default)
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "?", modifiers: .shift)),
                       .matched(.showCommandPalette))
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "P", modifiers: [.shift, .command])),
                       .matched(.showCommandPalette))
        XCTAssertTrue(KeyBindingSet.default.conflicts().isEmpty)
    }

    func testSelectedItemOperationCommandsHaveNoDefaultKeyBindings() {
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .copySelectedItem), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .moveSelectedItem), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .trashSelectedItem), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .showOpenWithMenu), [])
    }

    func testResolverWaitsForSecondStrokeAndResolvesSequence() {
        let resolver = KeymapResolver()

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "S")),
            .awaitingNextStroke(
                PendingKeySequence(strokes: [KeyStroke(key: "S")])
            )
        )
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "F")), .matched(.sortByName))
    }

    func testResolverResolvesSingleStrokeCommand() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "C")), .matched(.copyMarkedItems))
    }

    func testResolverResolvesClipboardCopySequences() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "P")), .awaitingNextStroke(PendingKeySequence(strokes: [KeyStroke(key: "P")])))
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "1")), .matched(.copyFileNamesToClipboard))
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "P")), .awaitingNextStroke(PendingKeySequence(strokes: [KeyStroke(key: "P")])))
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "2")), .matched(.copyDirectoryPathsToClipboard))
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "P")), .awaitingNextStroke(PendingKeySequence(strokes: [KeyStroke(key: "P")])))
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "3")), .matched(.copyFullPathsToClipboard))
    }

    func testResolverResolvesCommandReturnAsOpenSelectedItem() {
        let resolver = KeymapResolver()

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "Return", modifiers: .command)),
            .matched(.openSelectedItem)
        )
    }

    func testUnmodifiedReturnIsNotInDefaultKeyBindings() {
        let resolver = KeymapResolver()

        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openSelectedDirectory), [])
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "Return")), .unmatched)
    }

    func testReservingUnmodifiedReturnKeepsModifiedReturnAndOtherBindings() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .openSelectedDirectory, sequences: [
                .init(.init(key: "Return")),
                .init(.init(key: "Return", modifiers: .option)),
                .init(.init(key: "G"))
            ]),
            KeyBindingEntry(commandID: .previewSelectedFile, sequences: [.init(.init(key: "Return"))])
        ])

        let reserved = set.reservingUnmodifiedReturn()

        XCTAssertEqual(
            reserved.sequences(for: .openSelectedDirectory),
            [.init(.init(key: "Return", modifiers: .option)), .init(.init(key: "G"))]
        )
        XCTAssertEqual(reserved.sequences(for: .previewSelectedFile), [])
    }

    func testResolverResolvesDAsTrashMarkedItems() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "D")), .matched(.trashMarkedItems))
    }

    func testResolverResolvesVAsPreviewSelectedFile() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "V")), .matched(.previewSelectedFile))
    }

    func testResolverResolvesPreviewPaneCommands() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "V", modifiers: .shift)), .matched(.togglePreviewPane))
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "V", modifiers: .option)), .matched(.enterPreviewMode))
    }

    func testResolverFiltersCommandsByExecutionScope() {
        let resolver = KeymapResolver()
        let applicationCommands = Set(CommandID.allCases.filter { $0.executionScope == .application })

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "Q"), allowedCommandIDs: applicationCommands),
            .matched(.quitApplication)
        )
        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "Tab"), allowedCommandIDs: applicationCommands),
            .unmatched
        )
    }

    func testPreviewKeymapResolverResolvesQAsEndPreview() {
        let resolver = PreviewKeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "Q")), .endPreview)
        XCTAssertNil(resolver.resolve(KeyStroke(key: "Q", modifiers: .command)))
    }

    func testResolverResolvesShiftRAsCopySelectedItemWithNewName() {
        let resolver = KeymapResolver()

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "R", modifiers: .shift)),
            .matched(.copySelectedItemWithNewName)
        )
    }

    func testResolverResolvesTAsTagFilterList() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "T")), .matched(.showTagFilterList))
    }

    func testResolverResolvesShiftTAsTagEditList() {
        let resolver = KeymapResolver()

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "T", modifiers: .shift)),
            .matched(.showTagEditList)
        )
    }

    func testResolverResolvesShiftJAsDirectPathInput() {
        let resolver = KeymapResolver()

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "J", modifiers: .shift)),
            .matched(.beginDirectPathInput)
        )
    }

    func testResolverResolvesIAsShowSelectedItemInfo() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "I")), .matched(.showSelectedItemInfo))
    }

    func testToggleHiddenFilesHasNoDefaultBinding() {
        let resolver = KeymapResolver()

        XCTAssertEqual(KeyBindingSet.default.sequences(for: .toggleHiddenFiles), [])
        XCTAssertEqual(resolver.resolve(KeyStroke(key: ".")), .unmatched)
    }

    func testJumpPathOpenCommandsHaveNoDefaultBindings() {
        let resolver = KeymapResolver()

        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath1), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath2), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath3), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath4), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath5), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath6), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath7), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath8), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath9), [])
        XCTAssertEqual(KeyBindingSet.default.sequences(for: .openJumpPath0), [])
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "1")), .unmatched)
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "0")), .unmatched)
    }

    func testResolverResolvesCustomToggleHiddenFilesBinding() {
        var set = KeyBindingSet.default
        set.addSequence(KeyBindingSequence(KeyStroke(key: ".", modifiers: .command)), to: .toggleHiddenFiles)
        let resolver = KeymapResolver(keyBindingSet: set)

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: ".", modifiers: .command)),
            .matched(.toggleHiddenFiles)
        )
    }

    func testResolverResolvesCustomJumpPathOpenBindings() {
        var set = KeyBindingSet.default
        set.addSequence(KeyBindingSequence(KeyStroke(key: "1", modifiers: .control)), to: .openJumpPath1)
        set.addSequence(KeyBindingSequence(KeyStroke(key: "0", modifiers: .control)), to: .openJumpPath0)
        let resolver = KeymapResolver(keyBindingSet: set)

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "1", modifiers: .control)),
            .matched(.openJumpPath1)
        )
        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "0", modifiers: .control)),
            .matched(.openJumpPath0)
        )
    }

    func testResolverResolvesEndAsClearMarkedItems() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "End")), .matched(.clearMarkedItems))
    }

    func testResolverResolvesPageUpAndPageDownAsPageSelectionMovement() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "PageUp")), .matched(.moveSelectionPageUp))
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "PageDown")), .matched(.moveSelectionPageDown))
    }

    func testResolverResolvesControlShiftSpaceAsMarkRangeFromPreviousMarkedItem() {
        let resolver = KeymapResolver()

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "Space", modifiers: [.control, .shift])),
            .matched(.markRangeFromPreviousMarkedItem)
        )
    }

    func testResolverDoesNotUseUnderscoreAsDefaultContextMenuShortcut() {
        let resolver = KeymapResolver()

        XCTAssertEqual(resolver.resolve(KeyStroke(key: "_")), .unmatched)
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "_", modifiers: .shift)), .unmatched)
    }

    func testResolverResolvesMultipleSimultaneousModifiers() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(
                commandID: .copyMarkedItems,
                sequences: [.init(.init(key: "C", modifiers: [.control, .option, .shift, .command]))]
            )
        ])
        let resolver = KeymapResolver(keyBindingSet: set)

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "C", modifiers: [.control, .option, .shift, .command])),
            .matched(.copyMarkedItems)
        )
    }

    func testKeyStrokeDisplayTextShowsMultipleModifiers() {
        let stroke = KeyStroke(key: "C", modifiers: [.control, .option, .shift, .command])

        XCTAssertEqual(stroke.displayText, "Control+Option+Shift+Cmd+C")
    }

    func testResolverClearsPendingStrokesAfterUnmatchedSequence() {
        let resolver = KeymapResolver()

        XCTAssertEqual(
            resolver.resolve(KeyStroke(key: "S")),
            .awaitingNextStroke(
                PendingKeySequence(strokes: [KeyStroke(key: "S")])
            )
        )
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "X")), .unmatched)
        XCTAssertEqual(resolver.resolve(KeyStroke(key: "C")), .matched(.copyMarkedItems))
    }

    func testResolverReportsPendingSequenceDisplayText() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(
                commandID: .copyMarkedItems,
                sequences: [.init([.init(key: "G"), .init(key: "C")])]
            )
        ])
        let resolver = KeymapResolver(keyBindingSet: set)

        let resolution = resolver.resolve(KeyStroke(key: "G"))

        XCTAssertEqual(
            resolution,
            .awaitingNextStroke(
                PendingKeySequence(strokes: [KeyStroke(key: "G")])
            )
        )
        guard case .awaitingNextStroke(let pendingSequence) = resolution else {
            return XCTFail("2ストローク目待機になること")
        }
        XCTAssertEqual(pendingSequence.displayText, "G")
    }

    func testResolverReturnsCandidatesForPendingSequence() {
        let resolver = KeymapResolver()
        let pendingSequence = PendingKeySequence(strokes: [KeyStroke(key: "S")])

        XCTAssertEqual(
            resolver.candidates(for: pendingSequence),
            [
                KeyBindingCandidate(commandID: .sortBySize, remainingStrokes: [KeyStroke(key: "S")]),
                KeyBindingCandidate(commandID: .sortByExtension, remainingStrokes: [KeyStroke(key: "E")]),
                KeyBindingCandidate(commandID: .sortByName, remainingStrokes: [KeyStroke(key: "F")]),
                KeyBindingCandidate(commandID: .sortByModificationDate, remainingStrokes: [KeyStroke(key: "T")])
            ]
        )
    }

    func testResolverReturnsAllRemainingStrokesForLongCandidate() {
        let resolver = KeymapResolver(keyBindingSet: KeyBindingSet(entries: [
            KeyBindingEntry(
                commandID: .copyMarkedItems,
                sequences: [.init([.init(key: "G"), .init(key: "C"), .init(key: "X")])]
            )
        ]))

        XCTAssertEqual(
            resolver.candidates(for: PendingKeySequence(strokes: [KeyStroke(key: "G")])),
            [KeyBindingCandidate(commandID: .copyMarkedItems, remainingStrokes: [KeyStroke(key: "C"), KeyStroke(key: "X")])]
        )
    }

    func testKeyBindingSetDetectsDuplicateConflicts() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init(.init(key: "C"))]),
            KeyBindingEntry(commandID: .moveMarkedItems, sequences: [.init(.init(key: "C"))])
        ])

        XCTAssertEqual(set.conflicts(), [
            KeyBindingConflict(
                kind: .duplicate,
                firstCommandID: .copyMarkedItems,
                secondCommandID: .moveMarkedItems,
                sequence: KeyBindingSequence(KeyStroke(key: "C"))
            )
        ])
    }

    func testKeyBindingSetDetectsPrefixConflicts() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init(.init(key: "S"))]),
            KeyBindingEntry(commandID: .sortByName, sequences: [.init([.init(key: "S"), .init(key: "F")])])
        ])

        XCTAssertEqual(set.conflicts(), [
            KeyBindingConflict(
                kind: .prefix,
                firstCommandID: .copyMarkedItems,
                secondCommandID: .sortByName,
                sequence: KeyBindingSequence(KeyStroke(key: "S"))
            )
        ])
    }

    func testKeyBindingSetDetectsPrefixConflictWithinOneCommand() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [
                .init(.init(key: "S")),
                .init([.init(key: "S"), .init(key: "F")])
            ])
        ])

        XCTAssertEqual(set.conflicts(), [
            KeyBindingConflict(kind: .prefix, firstCommandID: .copyMarkedItems,
                               secondCommandID: .copyMarkedItems,
                               sequence: .init(.init(key: "S")))
        ])
    }

    func testKeyBindingSetDetectsDuplicateWithinOneCommand() {
        let sequence = KeyBindingSequence(KeyStroke(key: "C"))
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [sequence, sequence])
        ])

        XCTAssertEqual(set.conflicts(), [
            KeyBindingConflict(kind: .duplicate, firstCommandID: .copyMarkedItems,
                               secondCommandID: .copyMarkedItems, sequence: sequence)
        ])
    }

    func testKeyBindingSetMovesOnlySelectedSequence() {
        var set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [
                .init(.init(key: "C")), .init(.init(key: "V"))
            ]),
            KeyBindingEntry(commandID: .moveMarkedItems, sequences: [])
        ])

        XCTAssertTrue(set.moveSequence(.init(.init(key: "C")), from: .copyMarkedItems, to: .moveMarkedItems))
        XCTAssertEqual(set.sequences(for: .copyMarkedItems), [.init(.init(key: "V"))])
        XCTAssertEqual(set.sequences(for: .moveMarkedItems), [.init(.init(key: "C"))])
    }

    func testKeyBindingSetAssignsPreviouslyUnassignedSequence() {
        var set = KeyBindingSet.default
        let sequence = KeyBindingSequence(KeyStroke(key: "U", modifiers: .control))

        XCTAssertTrue(set.canAssign(sequence))
        XCTAssertTrue(set.assignSequence(sequence, to: .copySelectedItem))
        XCTAssertFalse(set.canAssign(sequence))
        XCTAssertEqual(set.sequences(for: .copySelectedItem), [sequence])
        XCTAssertEqual(set.bindings(startingWith: sequence.strokes).filter { $0.sequence == sequence }.count, 1)
    }

    func testKeyBindingSetRejectsUnassignedPrefixConflictWithoutChangingState() {
        var set = KeyBindingSet.default
        let original = set

        XCTAssertFalse(set.canAssign(.init(.init(key: "S"))))
        XCTAssertFalse(set.assignSequence(.init(.init(key: "S")), to: .copySelectedItem))
        XCTAssertEqual(set, original)
    }

    func testKeyBindingSetRejectsReservedReturnAssignment() {
        var set = KeyBindingSet.default
        let original = set

        XCTAssertFalse(set.assignSequence(.init(.init(key: "Return")), to: .copySelectedItem))
        XCTAssertEqual(set, original)
    }

    func testKeyBindingSetLeavesBothCommandsUnchangedWhenMoveConflicts() {
        var set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init(.init(key: "S"))]),
            KeyBindingEntry(commandID: .moveMarkedItems, sequences: [.init([.init(key: "S"), .init(key: "F")])])
        ])
        let original = set

        XCTAssertFalse(set.moveSequence(.init(.init(key: "S")), from: .copyMarkedItems, to: .moveMarkedItems))
        XCTAssertEqual(set, original)
    }

    func testKeyBindingSearchIncludesLongerSequences() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init([.init(key: "S"), .init(key: "F")])]),
            KeyBindingEntry(commandID: .moveMarkedItems, sequences: [.init(.init(key: "M"))])
        ])

        XCTAssertEqual(set.bindings(startingWith: [.init(key: "S")]).map(\.commandID), [.copyMarkedItems])
        XCTAssertEqual(set.bindings(startingWith: [.init(key: "S")]).map(\.sequence),
                       [.init([.init(key: "S"), .init(key: "F")])])
    }

    func testKeyBindingSetDetectsJumpPathListBindingAsPrefixConflict() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .showJumpPathList, sequences: [.init(.init(key: "J"))]),
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init([.init(key: "J"), .init(key: "1")])])
        ])

        XCTAssertEqual(set.conflicts(), [
            KeyBindingConflict(
                kind: .prefix,
                firstCommandID: .showJumpPathList,
                secondCommandID: .copyMarkedItems,
                sequence: KeyBindingSequence(KeyStroke(key: "J"))
            )
        ])
    }

    func testKeyBindingSetTreatsDifferentModifierCombinationsAsDifferentBindings() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [
                .init(.init(key: "C", modifiers: [.control, .option]))
            ]),
            KeyBindingEntry(commandID: .moveMarkedItems, sequences: [
                .init(.init(key: "C", modifiers: [.control, .shift]))
            ])
        ])

        XCTAssertEqual(set.conflicts(), [])
    }

    func testResetCommandToDefaultRestoresDefaultBindings() {
        var set = KeyBindingSet.default
        set.setSequences([KeyBindingSequence(KeyStroke(key: "X"))], for: .copyMarkedItems)

        set.resetCommandToDefault(.copyMarkedItems)

        XCTAssertEqual(set.sequences(for: .copyMarkedItems), KeyBindingSet.default.sequences(for: .copyMarkedItems))
    }

    func testFillingMissingDefaultEntriesPreservesCustomBindingsAndAddsMissingCommands() {
        let set = KeyBindingSet(entries: [
            KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init(.init(key: "X"))])
        ])

        let merged = set.fillingMissingDefaultEntries()

        XCTAssertEqual(merged.sequences(for: .copyMarkedItems), [.init(.init(key: "X"))])
        XCTAssertEqual(merged.sequences(for: .showTagFilterList), [.init(.init(key: "T"))])
        XCTAssertEqual(merged.sequences(for: .showTagEditList), [.init(.init(key: "T", modifiers: .shift))])
        XCTAssertEqual(merged.sequences(for: .beginDirectPathInput), [.init(.init(key: "J", modifiers: .shift))])
        XCTAssertEqual(merged.sequences(for: .showSelectedItemInfo), [.init(.init(key: "I"))])
        XCTAssertEqual(merged.sequences(for: .trashMarkedItems), [.init(.init(key: "D"))])
        XCTAssertEqual(merged.sequences(for: .openSelectedItem), [.init(.init(key: "Return", modifiers: .command))])
        XCTAssertEqual(merged.sequences(for: .toggleHiddenFiles), [])
        XCTAssertEqual(merged.sequences(for: .openJumpPath1), [])
        XCTAssertEqual(merged.sequences(for: .openJumpPath0), [])
    }
}
