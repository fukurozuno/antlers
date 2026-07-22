import Foundation
import XCTest
@testable import MafxCore

final class TagServiceTests: XCTestCase {
    func testFileTagParsesFinderResourceValueWithColor() {
        let tag = FileTag(resourceValue: "重要\n6")

        XCTAssertEqual(tag, FileTag(name: "重要", color: .red))
    }

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var temporaryDirectory: URL!

    override func setUp() {
        super.setUp()
        suiteName = "MafxCoreTests.TagService.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MafxCoreTests.TagService.\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testTagsInItemsReturnsUniqueSortedTags() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let service = TagService(finderUserDefaults: nil)
        let items = [
            FileItem(url: root.appendingPathComponent("a"), isDirectory: false, tagNames: ["Work", "Personal"]),
            FileItem(url: root.appendingPathComponent("b"), isDirectory: false, tagNames: ["Work"]),
            FileItem(url: root.appendingPathComponent("c"), isDirectory: false, tagNames: [])
        ]

        XCTAssertEqual(service.tags(in: items).map(\.name), ["Personal", "Work"])
    }

    func testAllTagsReturnsFinderFavoriteTagNames() {
        userDefaults.set(["", "Red", "Work"], forKey: "FavoriteTagNames")
        let service = TagService(finderUserDefaults: userDefaults)

        XCTAssertEqual(service.allTags().map(\.name), ["Red", "Work"])
    }

    func testAllTagsAssignsFinderFavoriteTagColors() {
        userDefaults.set(["", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"], forKey: "FavoriteTagNames")
        let service = TagService(finderUserDefaults: userDefaults)

        let colorsByName = Dictionary(uniqueKeysWithValues: service.allTags().map { ($0.name, $0.color) })

        XCTAssertEqual(colorsByName["Red"], .red)
        XCTAssertEqual(colorsByName["Orange"], .orange)
        XCTAssertEqual(colorsByName["Yellow"], .yellow)
        XCTAssertEqual(colorsByName["Green"], .green)
        XCTAssertEqual(colorsByName["Blue"], .blue)
        XCTAssertEqual(colorsByName["Purple"], .purple)
        XCTAssertEqual(colorsByName["Gray"], .gray)
    }

    func testAllTagsReturnsFinderTagViewSettingsNames() {
        userDefaults.set(
            [
                "Work_Tag_ViewSettings": ["showIconPreview": true],
                "Important_Tag_ViewSettings": ["showIconPreview": false]
            ],
            forKey: "ViewSettings"
        )
        let service = TagService(finderUserDefaults: userDefaults)

        XCTAssertEqual(service.allTags().map(\.name), ["Important", "Work"])
    }

    func testTagsInItemsMergesFinderDefinedTagsAndItemTags() {
        userDefaults.set(["Red", "Work"], forKey: "FavoriteTagNames")
        let root = URL(fileURLWithPath: "/tmp/root")
        let service = TagService(finderUserDefaults: userDefaults)
        let items = [
            FileItem(url: root.appendingPathComponent("a"), isDirectory: false, tagNames: ["Personal"])
        ]

        XCTAssertEqual(service.tags(in: items).map(\.name), ["Personal", "Red", "Work"])
    }

    func testTagsInItemsParsesEncodedFinderTagColor() {
        let root = URL(fileURLWithPath: "/tmp/root")
        let service = TagService(finderUserDefaults: nil)
        let items = [
            FileItem(url: root.appendingPathComponent("a"), isDirectory: false, tagNames: ["Work\n6"])
        ]

        XCTAssertEqual(service.tags(in: items), [FileTag(name: "Work", color: .red)])
    }

    func testTagsInItemsKeepsFinderColorWhenItemTagHasNoColor() {
        userDefaults.set(["", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"], forKey: "FavoriteTagNames")
        let root = URL(fileURLWithPath: "/tmp/root")
        let service = TagService(finderUserDefaults: userDefaults)
        let items = [
            FileItem(url: root.appendingPathComponent("a"), isDirectory: false, tagNames: ["Red"])
        ]

        XCTAssertEqual(service.tags(in: items).first { $0.name == "Red" }, FileTag(name: "Red", color: .red))
    }

    func testItemsMatchingTagUsesProvidedURLsAndLoadsFileMetadata() throws {
        let file = temporaryDirectory.appendingPathComponent("tagged.txt")
        try "body".write(to: file, atomically: true, encoding: .utf8)
        try (file as NSURL).setResourceValue(["Work"], forKey: .tagNamesKey)
        let service = TagService(finderUserDefaults: nil, taggedURLProvider: { tag in
            XCTAssertEqual(tag, FileTag(name: "Work"))
            return [file]
        })

        let items = try service.items(matching: FileTag(name: "Work"))

        XCTAssertEqual(items.map(\.url), [file])
        XCTAssertEqual(items.first?.tagNames, ["Work"])
        XCTAssertEqual(items.first?.byteSize, 4)
    }
}
