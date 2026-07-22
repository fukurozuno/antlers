import Foundation
import XCTest
@testable import MafxCore

final class PaneStateTests: XCTestCase {
    func testBeginPreviewForSelectedFileStoresSelectedFileAndListPosition() {
        let fileURL = URL(fileURLWithPath: "/tmp/preview.txt")
        var state = PaneState(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            items: [FileItem(url: fileURL, isDirectory: false)]
        )

        XCTAssertTrue(state.beginPreviewForSelectedFile(topVisibleRow: 4))
        XCTAssertTrue(state.isPreviewing)
        XCTAssertEqual(state.previewItemURL, fileURL)
        XCTAssertEqual(state.previewStartTopVisibleRow, 4)
        XCTAssertEqual(state.endPreview(), 4)
        XCTAssertFalse(state.isPreviewing)
        XCTAssertNil(state.previewItemURL)
        XCTAssertNil(state.previewStartTopVisibleRow)
    }

    func testBeginPreviewForSelectedDirectoryDoesNothing() {
        let directoryURL = URL(fileURLWithPath: "/tmp/directory", isDirectory: true)
        var state = PaneState(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            items: [FileItem(url: directoryURL, isDirectory: true)]
        )

        XCTAssertFalse(state.beginPreviewForSelectedFile(topVisibleRow: 2))
        XCTAssertFalse(state.isPreviewing)
        XCTAssertNil(state.previewItemURL)
        XCTAssertNil(state.previewStartTopVisibleRow)
    }

    func testPreviewSelectionMovementSkipsDirectoriesAndUpdatesPreview() {
        let directoryURL = URL(fileURLWithPath: "/tmp/directory", isDirectory: true)
        let firstFileURL = URL(fileURLWithPath: "/tmp/first.txt")
        let secondFileURL = URL(fileURLWithPath: "/tmp/second.txt")
        var state = PaneState(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            items: [
                FileItem(url: firstFileURL, isDirectory: false),
                FileItem(url: directoryURL, isDirectory: true),
                FileItem(url: secondFileURL, isDirectory: false)
            ]
        )

        XCTAssertTrue(state.beginPreviewForSelectedFile(topVisibleRow: 0))
        XCTAssertTrue(state.movePreviewSelection(by: 1))
        XCTAssertEqual(state.selectedItem?.url, secondFileURL)
        XCTAssertEqual(state.previewItemURL, secondFileURL)

        XCTAssertTrue(state.movePreviewSelection(by: -1))
        XCTAssertEqual(state.selectedItem?.url, firstFileURL)
        XCTAssertEqual(state.previewItemURL, firstFileURL)
    }

    func testPreviewMarkAndMoveMarksCurrentFileThenPreviewsNextFile() {
        let firstFileURL = URL(fileURLWithPath: "/tmp/first.txt")
        let secondFileURL = URL(fileURLWithPath: "/tmp/second.txt")
        var state = PaneState(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            items: [
                FileItem(url: firstFileURL, isDirectory: false),
                FileItem(url: secondFileURL, isDirectory: false)
            ]
        )

        XCTAssertTrue(state.beginPreviewForSelectedFile(topVisibleRow: 0))
        state.toggleMarkForPreviewedFile(moveSelectionBy: 1)

        XCTAssertTrue(state.markedItemURLs.contains(firstFileURL))
        XCTAssertEqual(state.selectedItem?.url, secondFileURL)
        XCTAssertEqual(state.previewItemURL, secondFileURL)
    }

    func testMoveSelectionClampsToBounds() {
        let items = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a"), isDirectory: false),
            FileItem(url: URL(fileURLWithPath: "/tmp/b"), isDirectory: false)
        ]
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp"), items: items)

        state.moveSelection(by: 10)
        XCTAssertEqual(state.selectedIndex, 1)

        state.moveSelection(by: -10)
        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testMoveSelectionKeepsEmptyPaneAtZero() {
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp"))

        state.moveSelection(by: 1)

        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testMoveSelectionByPageUsesVisibleRowCountMinusOne() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let items = (0..<10).map { index in
            FileItem(url: root.appendingPathComponent("file-\(index)"), isDirectory: false)
        }
        var state = PaneState(currentDirectory: root, items: items)

        state.moveSelectionByPage(direction: 1, visibleRowCount: 5)

        XCTAssertEqual(state.selectedIndex, 4)

        state.moveSelectionByPage(direction: -1, visibleRowCount: 5)

        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testMoveSelectionByPageClampsToVisibleBounds() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let items = (0..<3).map { index in
            FileItem(url: root.appendingPathComponent("file-\(index)"), isDirectory: false)
        }
        var state = PaneState(currentDirectory: root, items: items)

        state.moveSelectionByPage(direction: 1, visibleRowCount: 20)
        XCTAssertEqual(state.selectedIndex, 2)

        state.moveSelectionByPage(direction: -1, visibleRowCount: 20)
        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testMoveSelectionByPageUsesVisibleItems() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("a.md"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("b.swift"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("c.md"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("d.swift"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("e.md"), isDirectory: false)
            ]
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("*.md")
        state.applyFileMaskAndEnd()
        state.moveSelectionByPage(direction: 1, visibleRowCount: 3)

        XCTAssertEqual(state.selectedItem?.name, "e.md")
        XCTAssertEqual(state.visibleSelectedIndex, 2)
    }

    func testApplyTagFilterLimitsVisibleItems() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("draft.md"), isDirectory: false, tagNames: ["Work"]),
                FileItem(url: root.appendingPathComponent("photo.jpg"), isDirectory: false, tagNames: ["Personal"]),
                FileItem(url: root.appendingPathComponent("notes.txt"), isDirectory: false, tagNames: ["Work", "Personal"])
            ]
        )

        state.applyTagFilter(FileTag(name: "Work"))

        XCTAssertEqual(state.visibleItems.map(\.name), ["draft.md", "notes.txt"])
        XCTAssertEqual(state.selectedItem?.name, "draft.md")
    }

    func testApplyTagFilterClampsSelectionToMatchingItem() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("draft.md"), isDirectory: false, tagNames: ["Work"]),
                FileItem(url: root.appendingPathComponent("photo.jpg"), isDirectory: false, tagNames: ["Personal"])
            ],
            selectedIndex: 1
        )

        state.applyTagFilter(FileTag(name: "Work"))

        XCTAssertEqual(state.selectedItem?.name, "draft.md")
        XCTAssertEqual(state.visibleSelectedIndex, 0)
    }

    func testClearTagFilterRestoresVisibleItems() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("draft.md"), isDirectory: false, tagNames: ["Work"]),
                FileItem(url: root.appendingPathComponent("photo.jpg"), isDirectory: false, tagNames: ["Personal"])
            ]
        )

        state.applyTagFilter(FileTag(name: "Work"))
        state.clearTagFilter()

        XCTAssertEqual(state.visibleItems.map(\.name), ["draft.md", "photo.jpg"])
        XCTAssertNil(state.tagFilterName)
    }

    func testApplyTagSearchResultsReplacesItemsAndSetsTagFilter() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let work = FileTag(name: "Work", color: .green)
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("local.txt"), isDirectory: false, tagNames: [])
            ],
            markedItemURLs: [root.appendingPathComponent("local.txt")]
        )
        let globalItem = URL(fileURLWithPath: "/tmp/other/global.txt")

        state.applyTagSearchResults([
            FileItem(url: globalItem, isDirectory: false, tagNames: ["Work"])
        ], tag: work)

        XCTAssertEqual(state.visibleItems.map(\.url), [globalItem])
        XCTAssertEqual(state.selectedItem?.url, globalItem)
        XCTAssertEqual(state.tagFilterName, "Work")
        XCTAssertEqual(state.tagFilterColor, .green)
        XCTAssertEqual(state.displayPath, "タグ: Work")
        XCTAssertTrue(state.markedItemURLs.isEmpty)
    }

    func testClearTagFilterClearsTagFilterColor() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(currentDirectory: root)

        state.applyTagFilter(FileTag(name: "Work", color: .blue))
        state.clearTagFilter()

        XCTAssertNil(state.tagFilterName)
        XCTAssertNil(state.tagFilterColor)
    }

    func testDisplayPathUsesCurrentDirectoryWhenTagFilterIsInactive() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let state = PaneState(currentDirectory: root)

        XCTAssertEqual(state.displayPath, root.path)
    }

    func testSelectItemUpdatesSelectedIndexWhenIndexExists() {
        let items = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a"), isDirectory: false),
            FileItem(url: URL(fileURLWithPath: "/tmp/b"), isDirectory: false)
        ]
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp"), items: items)

        state.selectItem(at: 1)

        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testSelectItemWithURLUpdatesSelectedIndexWhenItemExists() {
        let secondURL = URL(fileURLWithPath: "/tmp/b")
        let items = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a"), isDirectory: false),
            FileItem(url: secondURL, isDirectory: false)
        ]
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp"), items: items)

        state.selectItem(withURL: secondURL)

        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testSelectedItemByteSizeReflectsCurrentSelection() {
        let items = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a"), isDirectory: false, byteSize: 12),
            FileItem(url: URL(fileURLWithPath: "/tmp/b"), isDirectory: false, byteSize: 34)
        ]
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp"), items: items)

        XCTAssertEqual(state.selectedItemByteSize, 12)

        state.selectItem(at: 1)

        XCTAssertEqual(state.selectedItemByteSize, 34)
    }

    func testSelectedItemByteSizeIsNilForDirectory() {
        let items = [
            FileItem(url: URL(fileURLWithPath: "/tmp/directory"), isDirectory: true)
        ]
        let state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp"), items: items)

        XCTAssertNil(state.selectedItemByteSize)
    }

    func testSelectItemIgnoresOutOfBoundsIndex() {
        let items = [
            FileItem(url: URL(fileURLWithPath: "/tmp/a"), isDirectory: false)
        ]
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp"), items: items)

        state.selectItem(at: 3)

        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testToggleMarkForSelectedItemMarksAndUnmarksCurrentItem() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let file = root.appendingPathComponent("a.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: file, isDirectory: false)
            ]
        )

        state.toggleMarkForSelectedItem()

        XCTAssertEqual(state.markedItemURLs, [file])
        XCTAssertEqual(state.markedItems.map(\.url), [file])

        state.toggleMarkForSelectedItem()

        XCTAssertTrue(state.markedItemURLs.isEmpty)
        XCTAssertTrue(state.markedItems.isEmpty)
    }

    func testToggleMarkForSelectedItemIgnoresEmptyPane() {
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp/root"))

        state.toggleMarkForSelectedItem()

        XCTAssertTrue(state.markedItemURLs.isEmpty)
    }

    func testClipboardCopyTargetsUseSelectedItemWhenNoItemsAreMarked() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let selected = root.appendingPathComponent("selected.txt")
        let other = root.appendingPathComponent("other.txt")
        let state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: selected, isDirectory: false),
                FileItem(url: other, isDirectory: false)
            ]
        )

        XCTAssertEqual(state.clipboardCopyTargetItems.map(\.url), [selected])
    }

    func testClipboardCopyTargetsPreferAllMarkedItemsInListingOrder() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let first = root.appendingPathComponent("first.txt")
        let second = root.appendingPathComponent("second.txt")
        let third = root.appendingPathComponent("third.txt")
        let state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: first, isDirectory: false),
                FileItem(url: second, isDirectory: false),
                FileItem(url: third, isDirectory: false)
            ],
            markedItemURLs: [third, second]
        )

        XCTAssertEqual(state.clipboardCopyTargetItems.map(\.url), [second, third])
    }

    func testClipboardCopyTargetsIncludeSelectedParentDirectoryItem() {
        let directory = URL(fileURLWithPath: "/tmp/root/child")
        guard let parentItem = FileItem.parentDirectoryItem(for: directory) else {
            return XCTFail("Expected a parent directory item")
        }
        let state = PaneState(currentDirectory: directory, items: [parentItem])

        XCTAssertEqual(state.clipboardCopyTargetItems, [parentItem])
    }

    func testClearMarkedItemsRemovesAllMarks() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let fileA = root.appendingPathComponent("a.txt")
        let fileB = root.appendingPathComponent("b.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: fileA, isDirectory: false),
                FileItem(url: fileB, isDirectory: false)
            ],
            selectedIndex: 1,
            markedItemURLs: [fileA, fileB]
        )

        state.clearMarkedItems()

        XCTAssertTrue(state.markedItemURLs.isEmpty)
        XCTAssertTrue(state.markedItems.isEmpty)
        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testReloadCurrentDirectoryPreservesSelectedItemWhenItsIndexChanges() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let first = root.appendingPathComponent("first.txt")
        let selected = root.appendingPathComponent("selected.txt")
        let listingService = StubDirectoryListingService(contentsByDirectory: [
            root: [
                FileItem(url: first, isDirectory: false),
                FileItem(url: selected, isDirectory: false)
            ]
        ])
        var state = PaneState(
            currentDirectory: root,
            items: [FileItem(url: selected, isDirectory: false)]
        )

        state.reloadCurrentDirectory(using: listingService)

        XCTAssertEqual(state.selectedItem?.url, selected)
        XCTAssertEqual(state.selectedIndex, 2)
        XCTAssertEqual(listingService.requests, [
            DirectoryListingRequest(directory: root, includingHiddenFiles: false)
        ])
    }

    func testToggleMarkForSelectedItemMovesToNextVisibleItemWhenRequested() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let first = root.appendingPathComponent("first.txt")
        let second = root.appendingPathComponent("second.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: first, isDirectory: false),
                FileItem(url: second, isDirectory: false)
            ],
            selectedIndex: 0
        )

        state.toggleMarkForSelectedItem(moveSelectionBy: 1)

        XCTAssertEqual(state.markedItemURLs, [first])
        XCTAssertEqual(state.selectedItem?.url, second)
    }

    func testToggleMarkForSelectedItemMovesToPreviousVisibleItemWhenRequested() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let first = root.appendingPathComponent("first.txt")
        let second = root.appendingPathComponent("second.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: first, isDirectory: false),
                FileItem(url: second, isDirectory: false)
            ],
            selectedIndex: 1
        )

        state.toggleMarkForSelectedItem(moveSelectionBy: -1)

        XCTAssertEqual(state.markedItemURLs, [second])
        XCTAssertEqual(state.selectedItem?.url, first)
    }

    func testToggleMarkForSelectedItemMoveUsesVisibleItems() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let markdown = root.appendingPathComponent("note.md")
        let hiddenByMask = root.appendingPathComponent("main.swift")
        let readme = root.appendingPathComponent("README.md")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: markdown, isDirectory: false),
                FileItem(url: hiddenByMask, isDirectory: false),
                FileItem(url: readme, isDirectory: false)
            ],
            selectedIndex: 0
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("*.md")
        state.applyFileMaskAndEnd()
        state.toggleMarkForSelectedItem(moveSelectionBy: 1)

        XCTAssertEqual(state.markedItemURLs, [markdown])
        XCTAssertEqual(state.selectedItem?.url, readme)
    }

    func testToggleMarkForSelectedItemDoesNotMoveWhenNotRequested() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let first = root.appendingPathComponent("first.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: first, isDirectory: false),
                FileItem(url: root.appendingPathComponent("second.txt"), isDirectory: false)
            ],
            selectedIndex: 0
        )

        state.toggleMarkForSelectedItem()

        XCTAssertEqual(state.markedItemURLs, [first])
        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testMarkRangeFromPreviousMarkedItemToSelectedItemMarksVisibleRange() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let first = root.appendingPathComponent("first.txt")
        let second = root.appendingPathComponent("second.txt")
        let third = root.appendingPathComponent("third.txt")
        let fourth = root.appendingPathComponent("fourth.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: first, isDirectory: false),
                FileItem(url: second, isDirectory: false),
                FileItem(url: third, isDirectory: false),
                FileItem(url: fourth, isDirectory: false)
            ],
            selectedIndex: 3,
            markedItemURLs: [second]
        )

        state.markRangeFromPreviousMarkedItemToSelectedItem()

        XCTAssertEqual(state.markedItemURLs, [second, third, fourth])
        XCTAssertEqual(state.selectedIndex, 3)
    }

    func testMarkRangeFromPreviousMarkedItemToSelectedItemUsesNearestPreviousMark() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let first = root.appendingPathComponent("first.txt")
        let second = root.appendingPathComponent("second.txt")
        let third = root.appendingPathComponent("third.txt")
        let fourth = root.appendingPathComponent("fourth.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: first, isDirectory: false),
                FileItem(url: second, isDirectory: false),
                FileItem(url: third, isDirectory: false),
                FileItem(url: fourth, isDirectory: false)
            ],
            selectedIndex: 3,
            markedItemURLs: [first, third]
        )

        state.markRangeFromPreviousMarkedItemToSelectedItem()

        XCTAssertEqual(state.markedItemURLs, [first, third, fourth])
    }

    func testMarkRangeFromPreviousMarkedItemToSelectedItemDoesNothingWithoutPreviousMark() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let first = root.appendingPathComponent("first.txt")
        let second = root.appendingPathComponent("second.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: first, isDirectory: false),
                FileItem(url: second, isDirectory: false)
            ],
            selectedIndex: 1
        )

        state.markRangeFromPreviousMarkedItemToSelectedItem()

        XCTAssertTrue(state.markedItemURLs.isEmpty)
        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testMarkRangeFromPreviousMarkedItemToSelectedItemUsesVisibleItems() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let markdown = root.appendingPathComponent("note.md")
        let hiddenByMask = root.appendingPathComponent("main.swift")
        let readme = root.appendingPathComponent("README.md")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: markdown, isDirectory: false),
                FileItem(url: hiddenByMask, isDirectory: false),
                FileItem(url: readme, isDirectory: false)
            ],
            selectedIndex: 2,
            markedItemURLs: [markdown]
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("*.md")
        state.applyFileMaskAndEnd()
        state.markRangeFromPreviousMarkedItemToSelectedItem()

        XCTAssertEqual(state.markedItemURLs, [markdown, readme])
    }

    func testInvertMarkedFilesMarksAllVisibleFilesWhenNoFileIsMarked() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let fileA = root.appendingPathComponent("a.txt")
        let fileB = root.appendingPathComponent("b.txt")
        let directory = root.appendingPathComponent("directory")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: fileA, isDirectory: false),
                FileItem(url: directory, isDirectory: true),
                FileItem(url: fileB, isDirectory: false)
            ],
            markedItemURLs: [directory]
        )

        state.invertMarkedFiles()

        XCTAssertEqual(state.markedItemURLs, [fileA, fileB])
        XCTAssertEqual(state.markedItems.map(\.url), [fileA, fileB])
    }

    func testInvertMarkedFilesMarksVisibleFilesExceptCurrentlyMarkedFiles() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let fileA = root.appendingPathComponent("a.txt")
        let fileB = root.appendingPathComponent("b.txt")
        let fileC = root.appendingPathComponent("c.txt")
        let directory = root.appendingPathComponent("directory")
        let hiddenFromCurrentItems = root.appendingPathComponent(".hidden")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: fileA, isDirectory: false),
                FileItem(url: directory, isDirectory: true),
                FileItem(url: fileB, isDirectory: false),
                FileItem(url: fileC, isDirectory: false)
            ],
            markedItemURLs: [fileA, directory, hiddenFromCurrentItems]
        )

        state.invertMarkedFiles()

        XCTAssertEqual(state.markedItemURLs, [fileB, fileC])
        XCTAssertEqual(state.markedItems.map(\.url), [fileB, fileC])
    }

    func testInvertMarkedFilesIncludingDirectoriesMarksAllVisibleItemsWhenNoTargetIsMarked() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let file = root.appendingPathComponent("file.txt")
        let directory = root.appendingPathComponent("directory")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: file, isDirectory: false),
                FileItem(url: directory, isDirectory: true)
            ]
        )

        state.invertMarkedFiles(includingDirectories: true)

        XCTAssertEqual(state.markedItemURLs, [file, directory])
        XCTAssertEqual(state.markedItems.map(\.url), [file, directory])
    }

    func testInvertMarkedFilesIncludingDirectoriesMarksVisibleItemsExceptCurrentlyMarkedItems() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let fileA = root.appendingPathComponent("a.txt")
        let fileB = root.appendingPathComponent("b.txt")
        let directoryA = root.appendingPathComponent("directory-a")
        let directoryB = root.appendingPathComponent("directory-b")
        let hiddenFromCurrentItems = root.appendingPathComponent(".hidden")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: fileA, isDirectory: false),
                FileItem(url: directoryA, isDirectory: true),
                FileItem(url: fileB, isDirectory: false),
                FileItem(url: directoryB, isDirectory: true)
            ],
            markedItemURLs: [fileA, directoryA, hiddenFromCurrentItems]
        )

        state.invertMarkedFiles(includingDirectories: true)

        XCTAssertEqual(state.markedItemURLs, [fileB, directoryB])
        XCTAssertEqual(state.markedItems.map(\.url), [fileB, directoryB])
    }

    func testMarkSameNamedFilesMarksVisibleFilesThatExistInOppositeItems() {
        let leftRoot = URL(fileURLWithPath: "/tmp/left")
        let rightRoot = URL(fileURLWithPath: "/tmp/right")
        let matchingFile = leftRoot.appendingPathComponent("same.txt")
        let uniqueFile = leftRoot.appendingPathComponent("left-only.txt")
        let directoryWithSameName = leftRoot.appendingPathComponent("directory")
        var state = PaneState(
            currentDirectory: leftRoot,
            items: [
                FileItem(url: matchingFile, isDirectory: false),
                FileItem(url: uniqueFile, isDirectory: false),
                FileItem(url: directoryWithSameName, isDirectory: true)
            ],
            markedItemURLs: [uniqueFile]
        )

        let markedCount = state.markSameNamedFiles(comparedWith: [
            FileItem(url: rightRoot.appendingPathComponent("same.txt"), isDirectory: false),
            FileItem(url: rightRoot.appendingPathComponent("directory"), isDirectory: true)
        ])

        XCTAssertEqual(markedCount, 1)
        XCTAssertEqual(state.markedItemURLs, [matchingFile, uniqueFile])
    }

    func testMarkSameNamedFilesCanRequireMatchingByteSize() {
        let leftRoot = URL(fileURLWithPath: "/tmp/left")
        let rightRoot = URL(fileURLWithPath: "/tmp/right")
        let sameSize = leftRoot.appendingPathComponent("same-size.txt")
        let differentSize = leftRoot.appendingPathComponent("different-size.txt")
        var state = PaneState(
            currentDirectory: leftRoot,
            items: [
                FileItem(url: sameSize, isDirectory: false, byteSize: 10),
                FileItem(url: differentSize, isDirectory: false, byteSize: 20)
            ]
        )

        let markedCount = state.markSameNamedFiles(
            comparedWith: [
                FileItem(url: rightRoot.appendingPathComponent("same-size.txt"), isDirectory: false, byteSize: 10),
                FileItem(url: rightRoot.appendingPathComponent("different-size.txt"), isDirectory: false, byteSize: 21)
            ],
            options: SameNamedFileMarkOptions(comparesByteSize: true)
        )

        XCTAssertEqual(markedCount, 1)
        XCTAssertEqual(state.markedItemURLs, [sameSize])
    }

    func testMarkSameNamedFilesCanRequireMatchingModificationDate() {
        let leftRoot = URL(fileURLWithPath: "/tmp/left")
        let rightRoot = URL(fileURLWithPath: "/tmp/right")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let matchingDate = leftRoot.appendingPathComponent("matching-date.txt")
        let differentDate = leftRoot.appendingPathComponent("different-date.txt")
        var state = PaneState(
            currentDirectory: leftRoot,
            items: [
                FileItem(url: matchingDate, isDirectory: false, modificationDate: date),
                FileItem(url: differentDate, isDirectory: false, modificationDate: date)
            ]
        )

        let markedCount = state.markSameNamedFiles(
            comparedWith: [
                FileItem(url: rightRoot.appendingPathComponent("matching-date.txt"), isDirectory: false, modificationDate: date),
                FileItem(
                    url: rightRoot.appendingPathComponent("different-date.txt"),
                    isDirectory: false,
                    modificationDate: date.addingTimeInterval(1)
                )
            ],
            options: SameNamedFileMarkOptions(comparesModificationDate: true)
        )

        XCTAssertEqual(markedCount, 1)
        XCTAssertEqual(state.markedItemURLs, [matchingDate])
    }

    func testMarkSameNamedFilesUsesVisibleItemsOnly() {
        let leftRoot = URL(fileURLWithPath: "/tmp/left")
        let rightRoot = URL(fileURLWithPath: "/tmp/right")
        let visible = leftRoot.appendingPathComponent("visible.md")
        let hiddenByMask = leftRoot.appendingPathComponent("hidden.swift")
        var state = PaneState(
            currentDirectory: leftRoot,
            items: [
                FileItem(url: visible, isDirectory: false),
                FileItem(url: hiddenByMask, isDirectory: false)
            ]
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("*.md")
        state.applyFileMaskAndEnd()
        let markedCount = state.markSameNamedFiles(comparedWith: [
            FileItem(url: rightRoot.appendingPathComponent("visible.md"), isDirectory: false),
            FileItem(url: rightRoot.appendingPathComponent("hidden.swift"), isDirectory: false)
        ])

        XCTAssertEqual(markedCount, 1)
        XCTAssertEqual(state.markedItemURLs, [visible])
    }

    func testWildcardMarkMarksItemsMatchingWildcardPattern() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let readme = root.appendingPathComponent("README.md")
        let source = root.appendingPathComponent("main.swift")
        let testSource = root.appendingPathComponent("PaneStateTests.swift")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: readme, isDirectory: false),
                FileItem(url: source, isDirectory: false),
                FileItem(url: testSource, isDirectory: false)
            ]
        )

        state.beginWildcardMark()
        state.updateWildcardMarkQuery("*.swift")
        state.markWildcardMatchesAndEnd()

        XCTAssertEqual(state.markedItemURLs, [source, testSource])
        XCTAssertFalse(state.isWildcardMarkActive)
        XCTAssertEqual(state.wildcardMarkQuery, "")
    }

    func testWildcardMarkUsesExactMatchWhenPatternHasNoWildcard() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let alpha = root.appendingPathComponent("Alpha.txt")
        let beta = root.appendingPathComponent("Beta.txt")
        let alphabet = root.appendingPathComponent("Alphabet.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: alpha, isDirectory: false),
                FileItem(url: beta, isDirectory: false),
                FileItem(url: alphabet, isDirectory: false)
            ]
        )

        state.beginWildcardMark()
        state.updateWildcardMarkQuery("Alpha.txt")
        state.markWildcardMatchesAndEnd()

        XCTAssertEqual(state.markedItemURLs, [alpha])
    }

    func testWildcardMarkKeepsExistingMarksAndCancelDoesNotMarkMatches() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let existing = root.appendingPathComponent("existing.txt")
        let match = root.appendingPathComponent("match.txt")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: existing, isDirectory: false),
                FileItem(url: match, isDirectory: false)
            ],
            markedItemURLs: [existing]
        )

        state.beginWildcardMark()
        state.updateWildcardMarkQuery("match.txt")
        state.endWildcardMark()

        XCTAssertEqual(state.markedItemURLs, [existing])

        state.beginWildcardMark()
        state.updateWildcardMarkQuery("match.txt")
        state.markWildcardMatchesAndEnd()

        XCTAssertEqual(state.markedItemURLs, [existing, match])
    }

    func testFileMaskUsesExactMatchWhenPatternHasNoWildcard() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("alpha"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("alphabet"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("alpha.txt"), isDirectory: false)
            ]
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("alpha")
        state.applyFileMaskAndEnd()

        XCTAssertFalse(state.isFileMaskInputActive)
        XCTAssertEqual(state.fileMaskPattern, "alpha")
        XCTAssertEqual(state.visibleItems.map(\.name), ["alpha"])
        XCTAssertEqual(state.selectedItem?.name, "alpha")
    }

    func testFileMaskSupportsWildcardEdges() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("notes.md"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("README.md"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("main.swift"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("src"), isDirectory: true)
            ]
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("*.md")
        state.applyFileMaskAndEnd()

        XCTAssertEqual(state.visibleItems.map(\.name), ["notes.md", "README.md"])

        state.beginFileMaskInput()
        state.updateFileMaskQuery("*s*")
        state.applyFileMaskAndEnd()

        XCTAssertEqual(state.visibleItems.map(\.name), ["notes.md", "main.swift", "src"])
    }

    func testFileMaskCancelKeepsPreviousAppliedMask() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("alpha"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("beta"), isDirectory: false)
            ]
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("alpha")
        state.applyFileMaskAndEnd()
        state.beginFileMaskInput()
        state.updateFileMaskQuery("beta")
        state.endFileMaskInput()

        XCTAssertEqual(state.fileMaskPattern, "alpha")
        XCTAssertEqual(state.visibleItems.map(\.name), ["alpha"])
    }

    func testFileMaskEmptyCommitClearsAppliedMask() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("alpha"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("beta"), isDirectory: false)
            ]
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("alpha")
        state.applyFileMaskAndEnd()
        state.beginFileMaskInput()
        state.updateFileMaskQuery("")
        state.applyFileMaskAndEnd()

        XCTAssertEqual(state.fileMaskPattern, "")
        XCTAssertEqual(state.visibleItems.map(\.name), ["alpha", "beta"])
    }

    func testFileMaskMovementAndVisibleSelectionUseVisibleRows() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("a.md"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("b.swift"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("c.md"), isDirectory: false)
            ]
        )

        state.beginFileMaskInput()
        state.updateFileMaskQuery("*.md")
        state.applyFileMaskAndEnd()

        XCTAssertEqual(state.visibleItems.map(\.name), ["a.md", "c.md"])
        XCTAssertEqual(state.visibleSelectedIndex, 0)

        state.moveSelection(by: 1)
        XCTAssertEqual(state.selectedItem?.name, "c.md")
        XCTAssertEqual(state.visibleSelectedIndex, 1)

        state.selectVisibleItem(at: 0)
        XCTAssertEqual(state.selectedItem?.name, "a.md")
    }

    func testBeginIncrementalSearchShowsEmptyQuery() {
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp/root"))

        state.beginIncrementalSearch()

        XCTAssertTrue(state.isIncrementalSearchActive)
        XCTAssertEqual(state.incrementalSearchQuery, "")
    }

    func testAppendIncrementalSearchTextSelectsFirstPrefixMatchFromCurrentSelection() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("Alpha.txt"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("Beta.txt"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("Bravo.txt"), isDirectory: false)
            ],
            selectedIndex: 1
        )

        state.beginIncrementalSearch()
        state.appendIncrementalSearchText("Br")

        XCTAssertEqual(state.incrementalSearchQuery, "Br")
        XCTAssertEqual(state.selectedItem?.name, "Bravo.txt")
    }

    func testIncrementalSearchUsesPrefixMatchWhenPatternHasNoWildcard() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("alphabet"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("alpha"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("alpha")

        XCTAssertEqual(state.selectedItem?.name, "alphabet")
    }

    func testIncrementalSearchAppliesPrefixModeToWildcardPatterns() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("aZxxc-tail"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("aZxxc"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("xaZxxc"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("a?*c")

        XCTAssertEqual(state.selectedItem?.name, "aZxxc-tail")
    }

    func testIncrementalSearchContainsModeAppliesWildcardsAtBothEdges() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("prefix-aZxxc-suffix"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("aZxxc"), isDirectory: false)
            ],
            incrementalSearchMatchMode: .contains
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("a?*c")

        XCTAssertEqual(state.selectedItem?.name, "prefix-aZxxc-suffix")
    }

    func testIncrementalSearchExactModeUsesWildcardPatternAsEntered() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("aZxxc-tail"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("aZxxc"), isDirectory: false)
            ],
            incrementalSearchMatchMode: .exact
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("a?*c")

        XCTAssertEqual(state.selectedItem?.name, "aZxxc")
    }

    func testChangingIncrementalSearchMatchModeUpdatesActiveSearch() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("alpha"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("prefix-abc-suffix"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("abc")
        XCTAssertEqual(state.selectedItem?.name, "alpha")

        state.setIncrementalSearchMatchMode(.contains)

        XCTAssertEqual(state.selectedItem?.name, "prefix-abc-suffix")
    }

    func testIncrementalSearchExcludesParentDirectoryItem() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = root.appendingPathComponent("child")
        let hiddenFile = child.appendingPathComponent(".gitignore")
        let service = StubDirectoryListingService(contentsByDirectory: [
            child: [FileItem(url: hiddenFile, isDirectory: false)]
        ])
        var state = PaneState(currentDirectory: child)

        state.loadCurrentDirectory(using: service)
        state.beginIncrementalSearch()
        state.appendIncrementalSearchText(".")

        XCTAssertEqual(state.selectedItem?.url, hiddenFile)
        XCTAssertFalse(state.selectedListItem?.isSpecialItem == true)
    }

    func testIncrementalSearchSupportsWildcardAsterisk() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("README.md"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("main.swift"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.appendIncrementalSearchText("*.swift")

        XCTAssertEqual(state.selectedItem?.name, "main.swift")
    }

    func testIncrementalSearchSupportsWildcardQuestionMark() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("file10.txt"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("file1.txt"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.appendIncrementalSearchText("file?.txt")

        XCTAssertEqual(state.selectedItem?.name, "file1.txt")
    }

    func testIncrementalSearchNextAndPreviousMatchWrapAround() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("apple.txt"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("banana.txt"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("apricot.txt"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.appendIncrementalSearchText("a*")
        XCTAssertEqual(state.selectedItem?.name, "apple.txt")

        state.selectNextIncrementalSearchMatch()
        XCTAssertEqual(state.selectedItem?.name, "apricot.txt")

        state.selectNextIncrementalSearchMatch()
        XCTAssertEqual(state.selectedItem?.name, "apple.txt")

        state.selectPreviousIncrementalSearchMatch()
        XCTAssertEqual(state.selectedItem?.name, "apricot.txt")
    }

    func testDeleteLastIncrementalSearchCharacterUpdatesQueryAndSelection() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("alpha"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("alpha.txt"), isDirectory: false)
            ],
            selectedIndex: 1
        )

        state.beginIncrementalSearch()
        state.appendIncrementalSearchText("alpha.txt")
        XCTAssertEqual(state.selectedItem?.name, "alpha.txt")

        for _ in 0..<4 {
            state.deleteLastIncrementalSearchCharacter()
        }

        XCTAssertEqual(state.incrementalSearchQuery, "alpha")
        XCTAssertEqual(state.selectedItem?.name, "alpha.txt")
    }

    func testUpdateIncrementalSearchQueryAcceptsJapaneseText() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("メモ.txt"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("資料.txt"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("資料.txt")

        XCTAssertEqual(state.incrementalSearchQuery, "資料.txt")
        XCTAssertEqual(state.selectedItem?.name, "資料.txt")
    }

    func testIncrementalSearchSupportsJapaneseTextWithAsciiWildcard() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("メモ.txt"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("資料.txt"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("資*.txt")

        XCTAssertEqual(state.selectedItem?.name, "資料.txt")
    }

    func testIncrementalSearchSupportsJapaneseTextWithFullWidthWildcard() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("メモ.txt"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("資料.txt"), isDirectory: false)
            ]
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("資＊.txt")

        XCTAssertEqual(state.selectedItem?.name, "資料.txt")
    }

    func testEndIncrementalSearchClearsQuery() {
        var state = PaneState(currentDirectory: URL(fileURLWithPath: "/tmp/root"))

        state.beginIncrementalSearch()
        state.appendIncrementalSearchText("a")
        state.endIncrementalSearch()

        XCTAssertFalse(state.isIncrementalSearchActive)
        XCTAssertEqual(state.incrementalSearchQuery, "")
    }

    func testMarkedItemsFollowCurrentItemsAfterSort() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let largeFile = root.appendingPathComponent("large.bin")
        let smallFile = root.appendingPathComponent("small.bin")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: largeFile, isDirectory: false, byteSize: 200),
                FileItem(url: smallFile, isDirectory: false, byteSize: 10)
            ],
            selectedIndex: 0
        )

        state.toggleMarkForSelectedItem()
        state.applySort(.byteSize)

        XCTAssertEqual(state.markedItemURLs, [largeFile])
        XCTAssertEqual(state.markedItems.map(\.url), [largeFile])
    }

    func testApplySortBySizeAndToggleDirectionWhenSameCriterionIsApplied() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("large.bin"), isDirectory: false, byteSize: 200),
                FileItem(url: root.appendingPathComponent("small.bin"), isDirectory: false, byteSize: 10)
            ]
        )

        state.applySort(.byteSize)

        XCTAssertEqual(state.items.map(\.name), ["small.bin", "large.bin"])
        XCTAssertEqual(state.sortDescriptor, FileSortDescriptor(criterion: .byteSize, direction: .ascending))

        state.applySort(.byteSize)

        XCTAssertEqual(state.items.map(\.name), ["large.bin", "small.bin"])
        XCTAssertEqual(state.sortDescriptor, FileSortDescriptor(criterion: .byteSize, direction: .descending))
    }

    func testApplySortByExtensionUsesNameAsTieBreaker() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("z.swift"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("a.md"), isDirectory: false),
                FileItem(url: root.appendingPathComponent("a.swift"), isDirectory: false)
            ]
        )

        state.applySort(.fileExtension)

        XCTAssertEqual(state.items.map(\.name), ["a.md", "a.swift", "z.swift"])
    }

    func testApplySortByModificationDate() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("new.txt"), isDirectory: false, modificationDate: newDate),
                FileItem(url: root.appendingPathComponent("old.txt"), isDirectory: false, modificationDate: oldDate)
            ]
        )

        state.applySort(.modificationDate)

        XCTAssertEqual(state.items.map(\.name), ["old.txt", "new.txt"])
    }

    func testApplySortKeepsDirectoriesBeforeFiles() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("a.txt"), isDirectory: false, byteSize: 1),
                FileItem(url: root.appendingPathComponent("z-dir"), isDirectory: true)
            ]
        )

        state.applySort(.byteSize)

        XCTAssertEqual(state.items.map(\.name), ["z-dir", "a.txt"])
    }

    func testApplySortPreservesSelectedItem() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("large.bin"), isDirectory: false, byteSize: 200),
                FileItem(url: root.appendingPathComponent("small.bin"), isDirectory: false, byteSize: 10)
            ],
            selectedIndex: 0
        )

        state.applySort(.byteSize)

        XCTAssertEqual(state.selectedItem?.name, "large.bin")
    }

    func testEnterSelectedDirectoryNavigatesToDirectoryAndLoadsContents() throws {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = root.appendingPathComponent("child")
        let loadedFileInChildDirectory = child.appendingPathComponent("loaded-file.txt")
        let service = StubDirectoryListingService(contentsByDirectory: [
            child: [
                FileItem(url: loadedFileInChildDirectory, isDirectory: false)
            ]
        ])
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: root.appendingPathComponent("file.txt"), isDirectory: false),
                FileItem(url: child, isDirectory: true)
            ],
            selectedIndex: 1,
            markedItemURLs: [root.appendingPathComponent("file.txt")]
        )

        let didEnter = state.enterSelectedDirectory(using: service)

        XCTAssertTrue(didEnter)
        XCTAssertEqual(state.currentDirectory, child)
        XCTAssertEqual(state.items, [
            FileItem.parentDirectoryItem(for: child),
            FileItem(url: loadedFileInChildDirectory, isDirectory: false)
        ].compactMap { $0 })
        XCTAssertEqual(state.selectedIndex, 0)
        XCTAssertTrue(state.markedItemURLs.isEmpty)
        XCTAssertNil(state.errorMessage)
    }

    func testEnterSelectedDirectoryIgnoresSelectedFile() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let file = root.appendingPathComponent("file.txt")
        let service = StubDirectoryListingService(contentsByDirectory: [:])
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: file, isDirectory: false)
            ]
        )

        let didEnter = state.enterSelectedDirectory(using: service)

        XCTAssertFalse(didEnter)
        XCTAssertEqual(state.currentDirectory, root)
        XCTAssertEqual(state.items, [FileItem(url: file, isDirectory: false)])
        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testMoveToParentDirectoryNavigatesToParentAndLoadsContents() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = root.appendingPathComponent("child")
        let siblingInParentDirectory = root.appendingPathComponent("sibling")
        let service = StubDirectoryListingService(contentsByDirectory: [
            root: [
                FileItem(url: child, isDirectory: true),
                FileItem(url: siblingInParentDirectory, isDirectory: true)
            ]
        ])
        var state = PaneState(
            currentDirectory: child,
            items: [
                FileItem(url: child.appendingPathComponent("file.txt"), isDirectory: false)
            ],
            selectedIndex: 0,
            markedItemURLs: [child.appendingPathComponent("file.txt")]
        )

        let didMove = state.moveToParentDirectory(using: service)

        XCTAssertTrue(didMove)
        XCTAssertEqual(state.currentDirectory, root)
        XCTAssertEqual(state.items, [
            FileItem.parentDirectoryItem(for: root),
            FileItem(url: child, isDirectory: true),
            FileItem(url: siblingInParentDirectory, isDirectory: true)
        ].compactMap { $0 })
        XCTAssertEqual(state.selectedIndex, 1)
        XCTAssertEqual(state.selectedItem?.url, child)
        XCTAssertTrue(state.markedItemURLs.isEmpty)
        XCTAssertNil(state.errorMessage)
    }

    func testMoveToParentDirectoryDoesNotSelectPreviousDirectoryWhenDisabled() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = root.appendingPathComponent("z-child")
        let sibling = root.appendingPathComponent("a-sibling")
        let service = StubDirectoryListingService(contentsByDirectory: [
            root: [
                FileItem(url: child, isDirectory: true),
                FileItem(url: sibling, isDirectory: true)
            ]
        ])
        var state = PaneState(currentDirectory: child)

        XCTAssertTrue(state.moveToParentDirectory(selectingPreviousDirectory: false, using: service))
        XCTAssertEqual(state.currentDirectory, root)
        XCTAssertNil(state.selectedItem)
        XCTAssertTrue(state.selectedListItem?.isParentDirectoryItem == true)
    }

    func testLoadCurrentDirectoryAddsParentDirectoryItemBeforeSortedRegularItems() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = root.appendingPathComponent("child")
        let service = StubDirectoryListingService(contentsByDirectory: [
            child: [
                FileItem(url: child.appendingPathComponent("z.txt"), isDirectory: false),
                FileItem(url: child.appendingPathComponent("a.txt"), isDirectory: false)
            ]
        ])
        var state = PaneState(currentDirectory: child)

        state.loadCurrentDirectory(using: service)

        XCTAssertEqual(state.visibleItems.map(\.name), ["..", "a.txt", "z.txt"])
        XCTAssertTrue(state.visibleItems[0].isParentDirectoryItem)
        XCTAssertEqual(state.selectedIndex, 0)
        XCTAssertNil(state.selectedItem)
        XCTAssertTrue(state.selectedListItem?.isParentDirectoryItem == true)
    }

    func testLoadCurrentDirectoryDoesNotAddParentDirectoryItemAtFileSystemRoot() {
        let root = URL(fileURLWithPath: "/")
        let service = StubDirectoryListingService(contentsByDirectory: [
            root: [FileItem(url: root.appendingPathComponent("tmp"), isDirectory: true)]
        ])
        var state = PaneState(currentDirectory: root)

        state.loadCurrentDirectory(using: service)

        XCTAssertEqual(state.visibleItems.map(\.name), ["tmp"])
    }

    func testParentDirectoryItemIsExcludedFromMarkingAndSorting() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = root.appendingPathComponent("child")
        let file = child.appendingPathComponent("file.txt")
        let service = StubDirectoryListingService(contentsByDirectory: [
            child: [FileItem(url: file, isDirectory: false)]
        ])
        var state = PaneState(currentDirectory: child)

        state.loadCurrentDirectory(using: service)
        state.toggleMarkForSelectedItem()
        state.invertMarkedFiles(includingDirectories: true)
        state.applySort(.byteSize)

        XCTAssertTrue(state.markedItemURLs.contains(file))
        XCTAssertFalse(state.markedItemURLs.contains(root))
        XCTAssertTrue(state.items.first?.isParentDirectoryItem == true)
    }

    func testMarkingParentDirectoryItemMovesToNextItemWithoutMarkingIt() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = root.appendingPathComponent("child")
        let file = child.appendingPathComponent("file.txt")
        let service = StubDirectoryListingService(contentsByDirectory: [
            child: [FileItem(url: file, isDirectory: false)]
        ])
        var state = PaneState(currentDirectory: child)

        state.loadCurrentDirectory(using: service)
        state.toggleMarkForSelectedItem(moveSelectionBy: 1)

        XCTAssertEqual(state.selectedItem?.url, file)
        XCTAssertTrue(state.markedItemURLs.isEmpty)
    }

    func testEnteringParentDirectoryItemMovesToParentDirectory() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = root.appendingPathComponent("child")
        let service = StubDirectoryListingService(contentsByDirectory: [
            root: [FileItem(url: child, isDirectory: true)]
        ])
        var state = PaneState(currentDirectory: child)

        state.loadCurrentDirectory(using: service)

        XCTAssertTrue(state.enterSelectedDirectory(using: service))
        XCTAssertEqual(state.currentDirectory, root)
        XCTAssertEqual(state.selectedItem?.url, child)
    }

    func testMoveToParentDirectoryIgnoresFileSystemRoot() {
        let root = URL(fileURLWithPath: "/")
        let service = StubDirectoryListingService(contentsByDirectory: [:])
        var state = PaneState(currentDirectory: root)

        let didMove = state.moveToParentDirectory(using: service)

        XCTAssertFalse(didMove)
        XCTAssertEqual(state.currentDirectory, root)
        XCTAssertEqual(state.items, [])
        XCTAssertEqual(state.selectedIndex, 0)
    }

    func testMoveToDirectoryNavigatesToSpecifiedDirectoryAndLoadsContents() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let destination = URL(fileURLWithPath: "/tmp/destination")
        let destinationFile = destination.appendingPathComponent("loaded.txt")
        let markedFile = root.appendingPathComponent("marked.txt")
        let service = StubDirectoryListingService(contentsByDirectory: [
            destination: [
                FileItem(url: destinationFile, isDirectory: false)
            ]
        ])
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: markedFile, isDirectory: false)
            ],
            selectedIndex: 0,
            markedItemURLs: [markedFile]
        )

        state.beginIncrementalSearch()
        state.updateIncrementalSearchQuery("marked.txt")
        state.moveToDirectory(destination, using: service)

        XCTAssertEqual(state.currentDirectory, destination)
        XCTAssertEqual(state.items, [
            FileItem.parentDirectoryItem(for: destination),
            FileItem(url: destinationFile, isDirectory: false)
        ].compactMap { $0 })
        XCTAssertEqual(state.selectedIndex, 0)
        XCTAssertTrue(state.markedItemURLs.isEmpty)
        XCTAssertFalse(state.isIncrementalSearchActive)
        XCTAssertEqual(state.incrementalSearchQuery, "")
        XCTAssertNil(state.errorMessage)
    }

    func testSetShowsHiddenFilesReloadsCurrentDirectoryThroughPaneState() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let visibleFile = root.appendingPathComponent("visible.txt")
        let hiddenFile = root.appendingPathComponent(".hidden")
        let service = StubDirectoryListingService(contentsByDirectory: [
            root: [
                FileItem(url: visibleFile, isDirectory: false),
                FileItem(url: hiddenFile, isDirectory: false)
            ]
        ])
        var state = PaneState(
            currentDirectory: root,
            items: [
                FileItem(url: visibleFile, isDirectory: false)
            ]
        )

        state.setShowsHiddenFiles(true, using: service)

        XCTAssertTrue(state.showsHiddenFiles)
        XCTAssertEqual(state.items.map(\.url), [
            root.deletingLastPathComponent(),
            hiddenFile,
            visibleFile
        ])
        XCTAssertEqual(service.requests, [
            DirectoryListingRequest(directory: root, includingHiddenFiles: true)
        ])
    }

    func testSetPaneWidthRatioClampsToAllowedRange() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(currentDirectory: root)

        state.setPaneWidthRatio(0.1)
        XCTAssertEqual(state.paneWidthRatio, 0.2)

        state.setPaneWidthRatio(0.9)
        XCTAssertEqual(state.paneWidthRatio, 0.8)

        state.setPaneWidthRatio(0.45)
        XCTAssertEqual(state.paneWidthRatio, 0.45)
    }

    func testAdjustPaneWidthRatioClampsToAllowedRange() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(currentDirectory: root, paneWidthRatio: 0.5)

        state.adjustPaneWidthRatio(by: 0.05)
        XCTAssertEqual(state.paneWidthRatio, 0.55)

        state.adjustPaneWidthRatio(by: 1.0)
        XCTAssertEqual(state.paneWidthRatio, 0.8)

        state.adjustPaneWidthRatio(by: -1.0)
        XCTAssertEqual(state.paneWidthRatio, 0.2)
    }

    func testSetMessageWindowHeightRatioClampsToAllowedRange() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(currentDirectory: root)

        state.setMessageWindowHeightRatio(0.05)
        XCTAssertEqual(state.messageWindowHeightRatio, 0.12)

        state.setMessageWindowHeightRatio(0.8)
        XCTAssertEqual(state.messageWindowHeightRatio, 0.45)

        state.setMessageWindowHeightRatio(0.2)
        XCTAssertEqual(state.messageWindowHeightRatio, 0.2)
    }

    func testAdjustMessageWindowHeightRatioClampsToAllowedRange() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(currentDirectory: root, messageWindowHeightRatio: 0.2)

        state.adjustMessageWindowHeightRatio(by: 0.05)
        XCTAssertEqual(state.messageWindowHeightRatio, 0.25, accuracy: 0.0001)

        state.adjustMessageWindowHeightRatio(by: 1.0)
        XCTAssertEqual(state.messageWindowHeightRatio, 0.45)

        state.adjustMessageWindowHeightRatio(by: -1.0)
        XCTAssertEqual(state.messageWindowHeightRatio, 0.12)
    }

    func testAppendMessageKeepsLatestMessages() {
        let root = URL(fileURLWithPath: "/tmp/root")
        var state = PaneState(currentDirectory: root)

        for index in 0..<205 {
            state.appendMessage("message \(index)")
        }

        XCTAssertEqual(state.messageLines.count, 200)
        XCTAssertEqual(state.messageLines.first, "message 5")
        XCTAssertEqual(state.messageLines.last, "message 204")
    }

    func testMoveToDirectoryRecordsNavigationHistory() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = URL(fileURLWithPath: "/tmp/root/child")
        let service = StubDirectoryListingService(contentsByDirectory: [:])
        var state = PaneState(currentDirectory: root)

        state.moveToDirectory(child, using: service)

        XCTAssertEqual(state.navigationHistory.paths, [root.path, child.path])
        XCTAssertEqual(state.navigationHistory.currentIndex, 1)
    }

    func testHistoryBackAndForwardMoveThroughPaneStateWithoutDuplicatingHistory() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let child = URL(fileURLWithPath: "/tmp/root/child")
        let service = StubDirectoryListingService(contentsByDirectory: [:])
        var state = PaneState(currentDirectory: root)
        state.moveToDirectory(child, using: service)

        XCTAssertTrue(state.moveBackwardInHistory(using: service))
        XCTAssertEqual(state.currentDirectory.path, root.path)
        XCTAssertEqual(state.navigationHistory.paths, [root.path, child.path])
        XCTAssertEqual(state.navigationHistory.currentIndex, 0)

        XCTAssertTrue(state.moveForwardInHistory(using: service))
        XCTAssertEqual(state.currentDirectory.path, child.path)
        XCTAssertEqual(state.navigationHistory.paths, [root.path, child.path])
        XCTAssertEqual(state.navigationHistory.currentIndex, 1)
    }
}

private final class StubDirectoryListingService: DirectoryListingProviding {
    let contentsByDirectory: [URL: [FileItem]]
    private(set) var requests: [DirectoryListingRequest] = []

    init(contentsByDirectory: [URL: [FileItem]]) {
        self.contentsByDirectory = contentsByDirectory
    }

    func contents(of directory: URL) throws -> [FileItem] {
        try contents(of: directory, includingHiddenFiles: false)
    }

    func contents(of directory: URL, includingHiddenFiles: Bool) throws -> [FileItem] {
        requests.append(DirectoryListingRequest(directory: directory, includingHiddenFiles: includingHiddenFiles))
        return contentsByDirectory[directory] ?? []
    }
}

private struct DirectoryListingRequest: Equatable {
    let directory: URL
    let includingHiddenFiles: Bool
}
