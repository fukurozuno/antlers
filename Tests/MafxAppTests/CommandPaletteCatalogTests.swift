import XCTest
import MafxCore
@testable import MafxApp

final class CommandPaletteCatalogTests: XCTestCase {
    func testJapaneseDisplaySearchesEnglishWithoutChangingDisplayLanguage() {
        L10n.setAppLanguage(.japanese)
        defer { L10n.setAppLanguage(.system) }
        let item = CommandPaletteCatalog.item(for: .trashSelectedItem, bindings: [])
        XCTAssertEqual(item.title, L10n.string(CommandID.trashSelectedItem.localizationKey))
        XCTAssertNotEqual(item.title, item.englishTitle)
        XCTAssertEqual(CommandPaletteSearch.results(for: "trash", in: [item]), [item])
        XCTAssertFalse(CommandPaletteSearch.englishMatchExplanation(for: "trash", in: item).isEmpty)
        XCTAssertEqual(L10n.string(CommandID.trashSelectedItem.localizationKey), item.title)
    }

    func testEnglishDisplayDoesNotSearchInactiveJapaneseLanguage() {
        L10n.setAppLanguage(.english)
        defer { L10n.setAppLanguage(.system) }
        let item = CommandPaletteCatalog.item(for: .trashSelectedItem, bindings: [])
        XCTAssertEqual(item.title, item.englishTitle)
        XCTAssertTrue(CommandPaletteSearch.results(for: "ゴミ箱", in: [item]).isEmpty)
        XCTAssertTrue(CommandPaletteSearch.englishMatchExplanation(for: "trash", in: item).isEmpty)
    }
}
